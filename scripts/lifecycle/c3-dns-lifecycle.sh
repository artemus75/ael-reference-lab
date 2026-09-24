#!/usr/bin/env bash

set -uo pipefail

# ---------------------------------------------------------------------------
# Architecture Engineering Lab
# C3 DNS Lifecycle Controller
#
# v0.5 — Configurable lifecycle discovery, scope validation, and guarded apply
#
# Responsibilities:
#   - enforce exclusive lifecycle-controller execution
#   - create a private per-run workspace
#   - execute a full OpenTofu discovery plan
#   - preserve OpenTofu exit semantics
#   - require human disruption classification
#   - execute the fleet-wide operational readiness gate
#   - consume the OpenTofu lifecycle metadata contract
#   - resolve lifecycle targets from OpenTofu metadata
#   - create saved target plans
#   - validate target-plan scope fail-closed
#   - apply exact saved target plans only after explicit operator approval
#
# Infrastructure convergence alone never proves operational readiness.
# ---------------------------------------------------------------------------

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd
)"
readonly DEFAULT_REPO_ROOT="$(
    cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd
)"

readonly REPO_ROOT="${C3_REPO_ROOT:-$DEFAULT_REPO_ROOT}"
readonly TOFU_DIR="${C3_TOFU_DIR:-${REPO_ROOT}/tofu/shared-infrastructure}"
readonly TOFU_VAR_FILE="${C3_TOFU_VAR_FILE:-environments/prod/terraform.tfvars}"
readonly SSH_PUBLIC_KEY_FILE="${C3_SSH_PUBLIC_KEY_FILE:-${HOME}/.ssh/id_ansible.pub}"

readonly HEALTH_GATE_PLAYBOOK="${C3_HEALTH_GATE_PLAYBOOK:-ansible/playbooks/dns-health-gate.yml}"
readonly TECHNITIUM_PLAYBOOK="${C3_TECHNITIUM_PLAYBOOK:-ansible/playbooks/technitium.yml}"
readonly LIFECYCLE_OUTPUT="${C3_LIFECYCLE_OUTPUT:-dns_lifecycle_resources}"

readonly C3_DOMAIN="${C3_DOMAIN:-production}"
readonly C3_RESOURCE_ROLE="${C3_RESOURCE_ROLE:-vm}"
readonly C3_ROLLING_ORDER_INPUT="${C3_ROLLING_ORDER:-dns-01 dns-02}"
readonly C3_KNOWN_DOMAINS_INPUT="${C3_KNOWN_DOMAINS:-production lab}"
read -r -a C3_ROLLING_ORDER <<<"$C3_ROLLING_ORDER_INPUT"
read -r -a C3_KNOWN_DOMAINS <<<"$C3_KNOWN_DOMAINS_INPUT"
readonly C3_ROLLING_ORDER
readonly C3_KNOWN_DOMAINS

readonly LOCK_FILE="${C3_LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/ael-c3-dns-lifecycle.lock}"

RUN_DIR=""

timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

log() {
    printf '[%s] %s\n' "$(timestamp)" "$*"
}

fail() {
    log "FAILED: $*"
    exit 1
}

cleanup() {
    local rc=$?

    if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" ]]; then
        rm -rf -- "$RUN_DIR"
    fi

    return "$rc"
}

acquire_workflow_lock() {
    log "Acquiring C3 lifecycle workflow lock"

    exec 9>"$LOCK_FILE" \
        || fail "Unable to open lifecycle lock: $LOCK_FILE"

    if ! flock -n 9; then
        log "STOPPED: another C3 DNS lifecycle controller owns the workflow lock"
        exit 2
    fi

    log "Lifecycle workflow lock acquired"
}

create_run_workspace() {
    umask 077

    RUN_DIR="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/ael-c3-dns.XXXXXX")" \
        || fail "Unable to create private lifecycle run workspace"

    [[ -d "$RUN_DIR" ]] \
        || fail "Lifecycle run workspace was not created"

    log "Private lifecycle run workspace created: $RUN_DIR"
}

validate_dependencies() {
    [[ -d "$TOFU_DIR" ]] \
        || fail "OpenTofu working directory does not exist: $TOFU_DIR"

    [[ -f "$TOFU_DIR/$TOFU_VAR_FILE" ]] \
        || fail "OpenTofu variable file does not exist: $TOFU_DIR/$TOFU_VAR_FILE"

    [[ -f "$REPO_ROOT/$HEALTH_GATE_PLAYBOOK" ]] \
        || fail "Health gate playbook does not exist: $REPO_ROOT/$HEALTH_GATE_PLAYBOOK"

    [[ -f "$SSH_PUBLIC_KEY_FILE" ]] \
        || fail "SSH public key does not exist: $SSH_PUBLIC_KEY_FILE"

    [[ -r "$SSH_PUBLIC_KEY_FILE" ]] \
        || fail "SSH public key is not readable: $SSH_PUBLIC_KEY_FILE"

    command -v tofu >/dev/null 2>&1 \
        || fail "OpenTofu executable 'tofu' was not found"

    command -v ansible-playbook >/dev/null 2>&1 \
        || fail "Ansible executable 'ansible-playbook' was not found"

    command -v jq >/dev/null 2>&1 \
        || fail "Required executable 'jq' was not found"

    command -v flock >/dev/null 2>&1 \
        || fail "Required executable 'flock' was not found"

    command -v sha256sum >/dev/null 2>&1 \
        || fail "Required executable 'sha256sum' was not found"

    [[ -n "${TF_VAR_proxmox_api_token:-}" ]] \
        || fail "Required environment variable TF_VAR_proxmox_api_token is not set"

    export TF_VAR_ssh_public_key
    TF_VAR_ssh_public_key="$(<"$SSH_PUBLIC_KEY_FILE")"

    [[ -n "$TF_VAR_ssh_public_key" ]] \
        || fail "SSH public key is empty: $SSH_PUBLIC_KEY_FILE"
}

load_lifecycle_metadata() {
    local metadata_file="${RUN_DIR}/dns-lifecycle-resources.json"

    log "Loading OpenTofu lifecycle metadata contract"

    (
        cd "$TOFU_DIR" || exit 1
        tofu output -json "$LIFECYCLE_OUTPUT"
    ) >"$metadata_file"

    local output_rc=$?

    if [[ "$output_rc" -ne 0 ]]; then
        fail "Unable to load OpenTofu lifecycle metadata contract"
    fi

    jq -e '
        type == "object" and
        length > 0 and
        all(
            .[];
            (.instance | type == "string") and
            (.lifecycle_domain | type == "string") and
            (.resource_role | type == "string")
        )
    ' "$metadata_file" >/dev/null \
        || fail "Lifecycle metadata contract has an unexpected structure"

    log "Lifecycle metadata contract loaded"
}

is_known_lifecycle_domain() {
    local candidate="$1"
    local known_domain

    for known_domain in "${C3_KNOWN_DOMAINS[@]}"; do
        if [[ "$candidate" == "$known_domain" ]]; then
            return 0
        fi
    done

    return 1
}

list_domain_instances() {
    local metadata_file="${RUN_DIR}/dns-lifecycle-resources.json"

    jq -r \
        --arg domain "$C3_DOMAIN" \
        --arg role "$C3_RESOURCE_ROLE" \
        '
        to_entries[]
        | select(
            .value.lifecycle_domain == $domain and
            .value.resource_role == $role
        )
        | .value.instance
        ' "$metadata_file" \
        | sort
}

resolve_target_address() {
    local target_instance="$1"
    local metadata_file="${RUN_DIR}/dns-lifecycle-resources.json"

    jq -er \
        --arg instance "$target_instance" \
        --arg domain "$C3_DOMAIN" \
        --arg role "$C3_RESOURCE_ROLE" \
        '
        [
            to_entries[]
            | select(
                .value.instance == $instance and
                .value.lifecycle_domain == $domain and
                .value.resource_role == $role
            )
        ]
        | if length == 1
          then .[0].key
          else empty
          end
        ' "$metadata_file"
}

run_full_discovery_plan() {
    log "Executing full read-only convergence plan"

    (
        cd "$TOFU_DIR" || exit 1

        tofu plan \
            -detailed-exitcode \
            -input=false \
            -var-file="$TOFU_VAR_FILE"
    )

    return $?
}

run_preflight_health_gate() {
    log "Phase: PRE-FLIGHT"
    log "Executing fleet-wide DNS operational health gate"

    (
        cd "$REPO_ROOT" || exit 1

        ansible-playbook \
            "$HEALTH_GATE_PLAYBOOK" \
            --ask-vault-pass
    )

    local gate_rc=$?

    if [[ "$gate_rc" -ne 0 ]]; then
        log "PRE-FLIGHT FAIL: fleet health gate failed with exit code $gate_rc"
        log "Lifecycle result: STOPPED"
        return 2
    fi

    log "PRE-FLIGHT PASS: production DNS fleet is operationally ready"
    return 0
}

request_apply_approval() {
    local target_instance="$1"
    local target_address="$2"
    local plan_file="$3"
    local approval
    local fingerprint

    fingerprint="$(cut -d' ' -f1 "${plan_file}.sha256")" \
        || fail "Unable to read target-plan fingerprint"

    printf '\n'
    log "CHANGE AUTHORITY APPROVAL REQUIRED"
    log "Target instance: $target_instance"
    log "OpenTofu resource: $target_address"
    log "Saved plan fingerprint: $fingerprint"
    printf '\n'
    printf 'Apply this exact saved plan? [yes/NO]: '

    read -r approval

    if [[ "$approval" != "yes" ]]; then
        log "APPLY NOT APPROVED"
        log "Lifecycle result: STOPPED"
        return 2
    fi

    log "APPLY APPROVED BY OPERATOR"
    return 0
}

apply_saved_target_plan() {
    local target_instance="$1"
    local plan_file="$2"
    local expected_fingerprint
    local actual_fingerprint

    log "Phase: APPLY"
    log "Verifying saved-plan integrity before change execution"

    [[ -f "$plan_file" ]] \
        || fail "Saved target plan does not exist: $plan_file"

    [[ -f "${plan_file}.sha256" ]] \
        || fail "Saved target-plan fingerprint does not exist"

    expected_fingerprint="$(cut -d' ' -f1 "${plan_file}.sha256")" \
        || fail "Unable to read saved target-plan fingerprint"

    actual_fingerprint="$(sha256sum "$plan_file" | cut -d' ' -f1)" \
        || fail "Unable to calculate target-plan fingerprint"

    if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
        log "APPLY FAIL: saved target-plan fingerprint changed after approval"
        return 2
    fi

    log "Saved-plan integrity PASS"
    log "Applying exact saved plan for $target_instance"

    (
        cd "$TOFU_DIR" || exit 1

        tofu apply \
            -input=false \
            "$plan_file"
    )

    local apply_rc=$?

    if [[ "$apply_rc" -ne 0 ]]; then
        log "APPLY FAIL: OpenTofu exited with code $apply_rc"
        return 2
    fi

    log "APPLY PASS: exact saved plan completed for $target_instance"
    return 0
}

reconcile_instance() {
    local target_instance="$1"

    log "Phase: RECONCILE"
    log "Reconciling Technitium desired state on $target_instance"

    (
        cd "$REPO_ROOT" || exit 1

        ansible-playbook \
            "$TECHNITIUM_PLAYBOOK" \
            --limit "$target_instance" \
            --ask-vault-pass
    )

    local reconcile_rc=$?

    if [[ "$reconcile_rc" -ne 0 ]]; then
        log "RECONCILE FAIL: $target_instance exited with code $reconcile_rc"
        return 2
    fi

    log "RECONCILE PASS: $target_instance"
    return 0
}

run_instance_health_gate() {
    local target_instance="$1"

    log "Phase: INSTANCE HEALTH GATE"
    log "Validating operational readiness of $target_instance"

    (
        cd "$REPO_ROOT" || exit 1

        ansible-playbook \
            "$HEALTH_GATE_PLAYBOOK" \
            --ask-vault-pass \
            -e "dns_health_gate_target=$target_instance"
    )

    local gate_rc=$?

    if [[ "$gate_rc" -ne 0 ]]; then
        log "INSTANCE GATE FAIL: $target_instance exited with code $gate_rc"
        return 2
    fi

    log "INSTANCE GATE PASS: $target_instance is operationally READY"
    return 0
}

process_instance() {
    local target_instance="$1"
    local target_address
    local plan_file
    local scope_rc

    log "============================================================"
    log "Lifecycle instance: $target_instance"

    target_address="$(resolve_target_address "$target_instance")" \
        || fail "Unable to resolve lifecycle target: $target_instance"

    plan_file="${RUN_DIR}/${target_instance}.plan"

    # -----------------------------------------------------------------------
    # Target Plan
    # -----------------------------------------------------------------------

    create_target_plan \
        "$target_instance" \
        "$target_address" \
        "$plan_file" \
        || {
            log "INSTANCE STOP: target plan failed for $target_instance"
            return 2
        }

    # -----------------------------------------------------------------------
    # Scope Guard / Target State
    # -----------------------------------------------------------------------

    validate_target_plan_scope \
        "$target_instance" \
        "$target_address" \
        "$plan_file"

    scope_rc=$?

    case "$scope_rc" in
        0)
            log "INSTANCE STATE: $target_instance -> CHANGED"
            log "Authorized infrastructure mutation requires operator approval"

            request_apply_approval \
                "$target_instance" \
                "$target_address" \
                "$plan_file" \
                || {
                    log "INSTANCE STOP: infrastructure change was not approved"
                    return 2
                }

            apply_saved_target_plan \
                "$target_instance" \
                "$plan_file" \
                || {
                    log "INSTANCE STOP: infrastructure apply failed for $target_instance"
                    return 2
                }

            log "INFRASTRUCTURE STATE: $target_instance -> CHANGED"
            ;;

        10)
            log "INSTANCE STATE: $target_instance -> ALREADY CONVERGED"
            log "Infrastructure mutation skipped"
            ;;

        *)
            log "INSTANCE STOP: scope validation rejected $target_instance"
            return 2
            ;;
    esac

    # -----------------------------------------------------------------------
    # Guest / Service Reconciliation
    #
    # This step is mandatory for BOTH paths:
    #   CHANGED
    #   ALREADY CONVERGED
    #
    # Infrastructure convergence alone does not imply operational readiness.
    # -----------------------------------------------------------------------

    reconcile_instance "$target_instance" \
        || {
            log "INSTANCE STOP: reconciliation failed for $target_instance"
            return 2
        }

    # -----------------------------------------------------------------------
    # Operational Readiness
    #
    # READY requires the complete L1-L6 contract.
    # -----------------------------------------------------------------------

    run_instance_health_gate "$target_instance" \
        || {
            log "INSTANCE STOP: operational readiness gate failed for $target_instance"
            return 2
        }

    log "INSTANCE COMPLETE: $target_instance -> READY"

    return 0
}

request_peer_approval() {
    local completed_instance="$1"
    local next_instance="$2"
    local approval

    printf '\n'
    log "REDUNDANCY BOUNDARY APPROVAL REQUIRED"
    log "Completed instance: $completed_instance -> READY"
    log "Next instance: $next_instance"
    log "The next redundant DNS instance will not be processed without explicit approval."
    printf '\n'
    printf 'Continue lifecycle with %s? [yes/NO]: ' "$next_instance"

    read -r approval

    if [[ "$approval" != "yes" ]]; then
        log "PEER TRANSITION NOT APPROVED"
        log "Lifecycle result: STOPPED"
        return 2
    fi

    log "PEER TRANSITION APPROVED BY OPERATOR"
    return 0
}

run_rolling_lifecycle() {
    local index
    local instance
    local next_instance

    log "Phase: ROLLING LIFECYCLE"
    log "Production rolling order: ${C3_ROLLING_ORDER[*]}"

    for ((index = 0; index < ${#C3_ROLLING_ORDER[@]}; index++)); do
        instance="${C3_ROLLING_ORDER[$index]}"

        process_instance "$instance" \
            || {
                log "ROLLING STOP: $instance did not reach READY"
                return 2
            }

        if (( index < ${#C3_ROLLING_ORDER[@]} - 1 )); then
            next_instance="${C3_ROLLING_ORDER[$((index + 1))]}"

            request_peer_approval \
                "$instance" \
                "$next_instance" \
                || return 2
        fi
    done

    log "ROLLING PASS: all production DNS instances reached READY"
    return 0
}

create_target_plan() {
    local target_instance="$1"
    local target_address="$2"
    local plan_file="$3"

    log "Phase: TARGET PLAN"
    log "Target instance: $target_instance"
    log "Resolved OpenTofu address: $target_address"

    (
        cd "$TOFU_DIR" || exit 1

        tofu plan \
            -input=false \
            -var-file="$TOFU_VAR_FILE" \
            -target="$target_address" \
            -out="$plan_file"
    )

    local plan_rc=$?

    if [[ "$plan_rc" -ne 0 ]]; then
        log "TARGET PLAN FAIL: OpenTofu failed with exit code $plan_rc"
        return 1
    fi

    chmod 600 "$plan_file" \
        || fail "Unable to restrict target-plan permissions"

    sha256sum "$plan_file" >"${plan_file}.sha256" \
        || fail "Unable to fingerprint target plan"

    log "Saved target plan created: $plan_file"
    log "Plan fingerprint: $(cut -d' ' -f1 "${plan_file}.sha256")"

    return 0
}

validate_target_plan_scope() {
    local target_instance="$1"
    local target_address="$2"
    local plan_file="$3"

    local plan_json="${RUN_DIR}/${target_instance}.plan.json"
    local changes_file="${RUN_DIR}/${target_instance}.changes.json"

    log "Phase: SCOPE VALIDATION"
    log "Inspecting saved target plan"

    (
        cd "$TOFU_DIR" || exit 1
        tofu show -json "$plan_file"
    ) >"$plan_json"

    local show_rc=$?

    if [[ "$show_rc" -ne 0 ]]; then
        log "SCOPE FAIL: unable to inspect saved target plan"
        return 1
    fi

    jq '
        [
            .resource_changes[]?
            | select(.change.actions != ["no-op"])
            | {
                address: .address,
                actions: .change.actions
            }
        ]
    ' "$plan_json" >"$changes_file" \
        || {
            log "SCOPE FAIL: unable to extract resource changes"
            return 1
        }

    local change_count
    change_count="$(jq 'length' "$changes_file")" \
        || {
            log "SCOPE FAIL: unable to count resource changes"
            return 1
        }

    if [[ "$change_count" -eq 0 ]]; then
        log "SCOPE PASS: target infrastructure is already converged"
        log "Target state: ALREADY CONVERGED"
        return 10
    fi

    if [[ "$change_count" -ne 1 ]]; then
        log "SCOPE FAIL: expected exactly one non-noop resource change; found $change_count"
        jq -r '.[] | "  \(.address) -> \(.actions | join(","))"' "$changes_file"
        return 2
    fi

    local planned_address
    local planned_actions

    planned_address="$(jq -r '.[0].address' "$changes_file")"
    planned_actions="$(jq -c '.[0].actions' "$changes_file")"

    if [[ "$planned_address" != "$target_address" ]]; then
        log "SCOPE FAIL: planned resource does not match resolved lifecycle target"
        log "Expected: $target_address"
        log "Actual:   $planned_address"
        return 2
    fi

    if [[ "$planned_actions" != '["update"]' ]]; then
        log "SCOPE FAIL: action is not permitted by C3 v0.4"
        log "Resource: $planned_address"
        log "Actions:  $planned_actions"
        return 2
    fi

    log "SCOPE PASS: exactly one authorized VM update"
    log "Authorized resource: $planned_address"
    log "Authorized actions: $planned_actions"

    return 0
}

validate_domain_metadata() {
    local instances=()
    local instance
    local address

    mapfile -t instances < <(list_domain_instances)

    if [[ "${#instances[@]}" -eq 0 ]]; then
        fail "Lifecycle metadata contains no '$C3_DOMAIN' '$C3_RESOURCE_ROLE' instances"
    fi

    log "Lifecycle domain: $C3_DOMAIN"
    log "Managed runtime instances: ${#instances[@]}"

    for instance in "${instances[@]}"; do
        address="$(resolve_target_address "$instance")" \
            || fail "Unable to resolve unique lifecycle resource for instance: $instance"

        log "Lifecycle target: $instance -> $address"
    done
}

validate_rolling_order() {
    local instance
    local address
    local metadata_instances
    local rolling_instances

    log "Validating explicit rolling lifecycle order"

    for instance in "${C3_ROLLING_ORDER[@]}"; do
        address="$(resolve_target_address "$instance")" \
            || fail "Rolling-order instance is not uniquely represented in lifecycle metadata: $instance"

        log "Rolling order member: $instance -> $address"
    done

    metadata_instances="$(
        list_domain_instances |
            sort -u
    )"

    rolling_instances="$(
        printf '%s\n' "${C3_ROLLING_ORDER[@]}" |
            sort -u
    )"

    if [[ "$metadata_instances" != "$rolling_instances" ]]; then
        log "ROLLING ORDER FAIL: rolling order does not exactly match lifecycle-domain membership"
        log "Metadata domain members:"
        printf '%s\n' "$metadata_instances"
        log "Configured rolling members:"
        printf '%s\n' "$rolling_instances"
        fail "Rolling lifecycle order and metadata contract differ"
    fi

    if [[ "$(printf '%s\n' "${C3_ROLLING_ORDER[@]}" | wc -l)" -ne \
          "$(printf '%s\n' "${C3_ROLLING_ORDER[@]}" | sort -u | wc -l)" ]]; then
        fail "Rolling lifecycle order contains duplicate instances"
    fi

    log "Rolling lifecycle order validated"
}

classify_change() {
    local classification

    printf '\n'
    log "Human classification required"
    printf '\n'
    printf 'Classify the planned change:\n'
    printf '\n'
    printf '  [d] POTENTIALLY DISRUPTIVE\n'
    printf '      Requires the C3 rolling lifecycle.\n'
    printf '\n'
    printf '  [n] NON-DISRUPTIVE\n'
    printf '      Operator determines that the rolling lifecycle is not required.\n'
    printf '\n'
    printf '  [a] ABORT\n'
    printf '      Stop without classifying the change.\n'
    printf '\n'

    read -r -p 'Classification [d/n/a]: ' classification

    case "$classification" in
        d|D)
            log "CLASSIFIED: POTENTIALLY DISRUPTIVE"
            log "C3 rolling lifecycle required"

            run_preflight_health_gate \
                || return 2

            printf '\n'
            log "ROLLING LIFECYCLE START APPROVAL REQUIRED"
            printf 'Start the production DNS rolling lifecycle? [yes/NO]: '

            local start_approval
            read -r start_approval

            if [[ "$start_approval" != "yes" ]]; then
                log "ROLLING LIFECYCLE NOT APPROVED"
                log "Lifecycle result: STOPPED"
                return 2
            fi

            log "ROLLING LIFECYCLE APPROVED BY OPERATOR"

            run_rolling_lifecycle \
                || return 2

            log "ROLLING LIFECYCLE COMPLETED"

            finalize_lifecycle
            return $?
            ;;

        n|N)
            log "CLASSIFIED: NON-DISRUPTIVE"
            log "No change will be executed by controller v0.4 validation stage"
            ;;

        a|A)
            log "ABORTED BY OPERATOR"
            ;;

        *)
            log "CLASSIFICATION FAIL: invalid operator response"
            ;;
    esac

    log "Lifecycle result: STOPPED"
    return 2
}

run_final_convergence_assessment() {
    local plan_file="${RUN_DIR}/final-convergence.plan"
    local plan_json="${RUN_DIR}/final-convergence.json"
    local metadata_file="${RUN_DIR}/dns-lifecycle-resources.json"
    local plan_rc
    local change_count
    local address
    local actions
    local metadata
    local instance
    local domain
    local role
    local other_domain_changes=0

    log "Phase: FINAL CONVERGENCE ASSESSMENT"
    log "Creating unrestricted OpenTofu plan"

    (
        cd "$TOFU_DIR" || exit 1

        tofu plan \
            -input=false \
            -var-file="$TOFU_VAR_FILE" \
            -out="$plan_file"
    )
    plan_rc=$?

    case "$plan_rc" in
        0|2)
            ;;
        *)
            log "FINAL CONVERGENCE FAIL: OpenTofu plan exited with code ${plan_rc}"
            return 2
            ;;
    esac

    chmod 600 "$plan_file" \
        || {
            log "FINAL CONVERGENCE FAIL: unable to protect saved plan"
            return 2
        }

    (
        cd "$TOFU_DIR" || exit 1
        tofu show -json "$plan_file"
    ) > "$plan_json" \
        || {
            log "FINAL CONVERGENCE FAIL: unable to inspect saved plan"
            return 2
        }

    chmod 600 "$plan_json" \
        || {
            log "FINAL CONVERGENCE FAIL: unable to protect plan JSON"
            return 2
        }

    change_count="$(
        jq '
            [
                .resource_changes[]?
                | select(.change.actions != ["no-op"])
            ]
            | length
        ' "$plan_json"
    )" || {
        log "FINAL CONVERGENCE FAIL: unable to count resource changes"
        return 2
    }

    if [[ "$change_count" -eq 0 ]]; then
        log "DOMAIN CONVERGENCE PASS: ${C3_DOMAIN} has no remaining infrastructure changes"
        log "GLOBAL CONVERGENCE PASS: no remaining infrastructure resource changes"
        return 0
    fi

    log "Final unrestricted plan contains ${change_count} non-noop resource change(s)"

    while IFS=$'\t' read -r address actions; do
        [[ -n "$address" ]] || continue

        log "Classifying remaining change: ${address} [${actions}]"

        metadata="$(
            jq -c --arg address "$address" '
                if has($address)
                then .[$address]
                else empty
                end
            ' "$metadata_file"
        )" || {
            log "FINAL CONVERGENCE FAIL: metadata lookup failed for ${address}"
            return 2
        }

        if [[ -z "$metadata" ]]; then
            log "FINAL CONVERGENCE FAIL: remaining change is not represented in lifecycle metadata"
            log "Unclassified resource: ${address}"
            return 2
        fi

        instance="$(jq -r '.instance // empty' <<<"$metadata")"
        domain="$(jq -r '.lifecycle_domain // empty' <<<"$metadata")"
        role="$(jq -r '.resource_role // empty' <<<"$metadata")"

        if [[ -z "$instance" || -z "$domain" || -z "$role" ]]; then
            log "FINAL CONVERGENCE FAIL: incomplete lifecycle metadata for ${address}"
            return 2
        fi

        if ! is_known_lifecycle_domain "$domain"; then
            log "FINAL CONVERGENCE FAIL: unknown lifecycle domain '${domain}'"
            log "Resource: ${address}"
            return 2
        fi

        if [[ "$role" != "vm" ]]; then
            log "FINAL CONVERGENCE FAIL: unsupported lifecycle resource role '${role}'"
            log "Resource: ${address}"
            return 2
        fi

        if [[ "$domain" == "$C3_DOMAIN" ]]; then
            log "DOMAIN CONVERGENCE FAIL: selected lifecycle domain still contains a change"
            log "Instance: ${instance}"
            log "Resource: ${address}"
            log "Actions: ${actions}"
            return 2
        fi

        log "Remaining change belongs to other lifecycle domain: ${domain}"
        ((other_domain_changes += 1))

    done < <(
        jq -r '
            .resource_changes[]?
            | select(.change.actions != ["no-op"])
            | [
                .address,
                (.change.actions | join(","))
              ]
            | @tsv
        ' "$plan_json"
    )

    if [[ "$other_domain_changes" -eq "$change_count" ]]; then
        log "DOMAIN CONVERGENCE PASS: ${C3_DOMAIN} has no remaining infrastructure changes"
        log "GLOBAL CONVERGENCE PENDING: ${other_domain_changes} change(s) remain in other known lifecycle domain(s)"
        return 10
    fi

    log "FINAL CONVERGENCE FAIL: unable to classify all remaining changes"
    return 2
}

finalize_lifecycle() {
    local convergence_rc

    log "Phase: LIFECYCLE FINALIZATION"

    run_final_convergence_assessment
    convergence_rc=$?

    case "$convergence_rc" in
        0)
            log "FINALIZATION: production domain is converged"
            log "FINALIZATION: global infrastructure is converged"
            ;;

        10)
            log "FINALIZATION: production domain is converged"
            log "FINALIZATION: global infrastructure has pending changes in other known lifecycle domain(s)"
            ;;

        *)
            log "FINALIZATION FAIL: convergence assessment failed"
            log "Lifecycle result: STOPPED"
            return 2
            ;;
    esac

    log "Phase: FINAL FLEET HEALTH GATE"

    run_preflight_health_gate
    local fleet_gate_rc=$?

    if [[ "$fleet_gate_rc" -ne 0 ]]; then
        log "FINALIZATION FAIL: final production DNS fleet health gate failed"
        log "Lifecycle result: STOPPED"
        return 2
    fi

    log "FINAL FLEET GATE PASS: production DNS fleet is operationally ready"
    log "DOMAIN COMPLETE: ${C3_DOMAIN}"

    case "$convergence_rc" in
        0)
            log "GLOBAL CONVERGENCE: CONVERGED"
            ;;
        10)
            log "GLOBAL CONVERGENCE: PENDING"
            ;;
    esac

    log "Lifecycle result: COMPLETE"
    return 0
}

offer_verification_resume() {
    local selection

    printf '\n'
    log "Infrastructure is globally converged"
    log "Infrastructure convergence does not prove operational lifecycle completion"
    printf '\n'

    printf 'Select action:\n'
    printf '\n'
    printf '  [v] VERIFY / RESUME\n'
    printf '      Reconcile and validate the production DNS lifecycle domain.\n'
    printf '\n'
    printf '  [e] EXIT\n'
    printf '      Accept infrastructure convergence and perform no lifecycle actions.\n'
    printf '\n'

    read -r -p 'Selection [v/e]: ' selection

    case "$selection" in
        v|V)
            log "VERIFY / RESUME selected"

            run_preflight_health_gate \
                || return 2

            printf '\n'
            log "VERIFY / RESUME START APPROVAL REQUIRED"
            log "Infrastructure mutation is not expected."
            log "Each lifecycle member will still be reconciled and health-gated."
            printf 'Start production DNS verification/resume? [yes/NO]: '

            local resume_approval
            read -r resume_approval

            if [[ "$resume_approval" != "yes" ]]; then
                log "VERIFY / RESUME NOT APPROVED"
                log "Lifecycle result: STOPPED"
                return 2
            fi

            log "VERIFY / RESUME APPROVED BY OPERATOR"

            run_rolling_lifecycle \
                || return 2

            log "VERIFY / RESUME ROLLING PASS"

            finalize_lifecycle
            return $?
            ;;

        e|E)
            log "Operator selected EXIT"
            log "Infrastructure is converged; operational lifecycle verification was not requested"
            log "Lifecycle result: CLEAN EXIT"
            return 0
            ;;

        *)
            log "VERIFY / RESUME FAIL: invalid operator response"
            log "Lifecycle result: STOPPED"
            return 2
            ;;
    esac
}

main() {
    trap cleanup EXIT

    log "C3 DNS lifecycle controller v0.4"
    log "Phase: DISCOVER"

    acquire_workflow_lock
    create_run_workspace
    validate_dependencies

    log "OpenTofu working directory: $TOFU_DIR"
    log "OpenTofu variable file: $TOFU_VAR_FILE"

    load_lifecycle_metadata
    validate_domain_metadata
    validate_rolling_order

    run_full_discovery_plan
    local tofu_rc=$?

    case "$tofu_rc" in
        0)
            log "DISCOVER PASS: infrastructure is converged"
            log "Operational lifecycle completion cannot be inferred from infrastructure convergence"

            offer_verification_resume
            return $?
            ;;

        2)
            log "DISCOVER: OpenTofu detected changes"
            log "No infrastructure changes have been executed"

            classify_change
            return $?
            ;;

        *)
            log "DISCOVER FAIL: OpenTofu plan failed with exit code $tofu_rc"
            log "Lifecycle result: FAILED"
            return "$tofu_rc"
            ;;
    esac
}

main "$@"

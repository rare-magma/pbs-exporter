#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(curl gzip jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

CURL=$(command -v curl)
GZIP=$(command -v gzip)
JQ=$(command -v jq)

[[ -z "${PBS_API_TOKEN_NAME}" ]] && echo >&2 "PBS_API_TOKEN_NAME is empty. Aborting" && exit 1
[[ -z "${PBS_API_TOKEN}" ]] && echo >&2 "PBS_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${PBS_URL}" ]] && echo >&2 "PBS_URL is empty. Aborting" && exit 1
[[ -z "${PUSHGATEWAY_URL}" ]] && echo >&2 "PUSHGATEWAY_URL is empty. Aborting" && exit 1

AUTH_HEADER="Authorization: PBSAPIToken=$PBS_API_TOKEN_NAME:$PBS_API_TOKEN"

pbs_json=$($CURL --silent --compressed --header "$AUTH_HEADER" "$PBS_URL/api2/json/status/datastore-usage")

mapfile -t parsed_stores < <(echo "$pbs_json" | $JQ --raw-output '.data[] | select(.avail !=-1) | .store')

if [ ${#parsed_stores[@]} -eq 0 ]; then
    echo >&2 "Couldn't parse any store from the PBS API. Aborting."
    exit 1
fi

for STORE in "${parsed_stores[@]}"; do

    mapfile -t parsed_backup_stats < <(echo "$pbs_json" | $JQ --raw-output ".data[] | select(.store==\"$STORE\") | .avail,.total,.used")

    available_value=${parsed_backup_stats[0]}
    size_value=${parsed_backup_stats[1]}
    used_value=${parsed_backup_stats[2]}

    store_status_json=$($CURL --silent --compressed --header "$AUTH_HEADER" "$PBS_URL/api2/json/admin/datastore/${STORE}/snapshots")

    [[ -z "${store_status_json}" ]] && echo >&2 "Couldn't parse any snapshot status from the PBS API for store=${STORE}. Aborting." && exit 1
    snapshot_count_value=$(echo "$store_status_json" | $JQ '.data | length')

    mapfile -t unique_vm_ids < <(echo "$store_status_json" | $JQ '.data | unique_by(."backup-id") | .[]."backup-id"')

    if [ ${#unique_vm_ids[@]} -eq 0 ]; then
        echo >&2 "Couldn't parse any VM IDs from the PBS API. Aborting."
        exit 1
    fi

    unset pbs_snapshot_vm_count_list
    for VM_ID in "${unique_vm_ids[@]}"; do
        snapshot_count_vm_value=$(echo "$store_status_json" | $JQ "reduce (.data[] | select(.\"backup-id\" == $VM_ID) | .\"backup-id\") as \$i (0;.+=1)")
        pbs_snapshot_vm_count_list+=$(printf "pbs_snapshot_vm_count {host=\"%s\", store=\"%s\", vm_id=%s} %s" "$HOSTNAME" "$STORE" "$VM_ID" "$snapshot_count_vm_value")
        pbs_snapshot_vm_count_list+=$'\n'
    done

    backup_stats=$(
        cat <<END_HEREDOC
# HELP pbs_available The available bytes of the underlying storage.
# TYPE pbs_available gauge
# HELP pbs_size The size of the underlying storage in bytes.
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage.
# TYPE pbs_used gauge
# HELP pbs_snapshot_count The total number of backups.
# TYPE pbs_snapshot_count gauge
# HELP pbs_snapshot_vm_count The total number of backups per VM.
# TYPE pbs_snapshot_vm_count gauge
pbs_available {host="$HOSTNAME", store="$STORE"} ${available_value}
pbs_size {host="$HOSTNAME", store="$STORE"} ${size_value}
pbs_used {host="$HOSTNAME", store="$STORE"} ${used_value}
pbs_snapshot_count {host="$HOSTNAME", store="$STORE"} ${snapshot_count_value}
${pbs_snapshot_vm_count_list}
END_HEREDOC
    )

    echo "$backup_stats" | $GZIP |
        $CURL --silent \
            --header 'Content-Encoding: gzip' \
            --data-binary @- \
            "${PUSHGATEWAY_URL}"/metrics/job/pbs_exporter/host/"$HOSTNAME"/store/"$STORE"

done

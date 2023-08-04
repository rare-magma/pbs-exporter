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

current_timestamp=$(date +%s)
twenty_four_hours_ago=$((current_timestamp - 86400))

# shellcheck source=/dev/null
source "$CREDENTIALS_DIRECTORY/creds"

[[ -z "${PBS_API_TOKEN_NAME}" ]] && echo >&2 "PBS_API_TOKEN_NAME is empty. Aborting" && exit 1
[[ -z "${PBS_API_TOKEN}" ]] && echo >&2 "PBS_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${PBS_URL}" ]] && echo >&2 "PBS_URL is empty. Aborting" && exit 1
[[ -z "${PUSHGATEWAY_URL}" ]] && echo >&2 "PUSHGATEWAY_URL is empty. Aborting" && exit 1

AUTH_HEADER="Authorization: PBSAPIToken=$PBS_API_TOKEN_NAME:$PBS_API_TOKEN"
PBS_CURL_OPTIONS=($PBS_CURL_OPTIONS --silent --fail --show-error --compressed --header "$AUTH_HEADER")
pbs_json="$($CURL "${PBS_CURL_OPTIONS[@]}" $PBS_URL/api2/json/status/datastore-usage)"

mapfile -t parsed_stores < <(echo "$pbs_json" | $JQ --raw-output '.data[] | select(.avail !=-1) | .store')

if [ ${#parsed_stores[@]} -eq 0 ]; then
    echo >&2 "Couldn't parse any store from the PBS API. Aborting."
    exit 1
fi

for STORE in "${parsed_stores[@]}"; do

    mapfile -t parsed_backup_stats < <(
        echo "$pbs_json" |
            $JQ --raw-output '.data[] | select(.store=="'$STORE'") | .avail,.total,.used,.["estimated-full-date"]'
    )

    available_value=${parsed_backup_stats[0]}
    size_value=${parsed_backup_stats[1]}
    used_value=${parsed_backup_stats[2]}
    estimated_full_date_value=${parsed_backup_stats[3]}

    # fetch namespaces
    namespaces_json="$(
        $CURL "${PBS_CURL_OPTIONS[@]}" "$PBS_URL/api2/json/admin/datastore/${STORE}/namespace"
    )"

    if [[ -z "${namespaces_json}" ]]; then
        echo >&2 "Couldn't retrieve any namespaces from PBS API for store=${STORE}. Skipping."
        continue
    fi

    mapfile -t parsed_namespaces < <(
        echo "$namespaces_json" |
            $JQ --raw-output '.data[] | select(.ns!="") | .ns'
    )

    namespaces=( "" "${parsed_namespaces[@]}" )
    store_snapshot_count_value=0
    for NAMESPACE in "${namespaces[@]}"; do
      store_status_json="$(
          $CURL "${PBS_CURL_OPTIONS[@]}" "$PBS_URL/api2/json/admin/datastore/${STORE}/snapshots?ns=$NAMESPACE"
      )"

      if [[ -z "${store_status_json}" ]]; then
          echo >&2 "Couldn't retrieve any snapshot status from the PBS API for store=${STORE}. Skipping."
          continue
      fi

      namespace_snapshot_count_value=$(echo "$store_status_json" | $JQ '.data | length')
      store_snapshot_count_value=$((store_snapshot_count_value + namespace_snapshot_count_value))

      mapfile -t unique_vm_ids < <(
          echo "$store_status_json" |
              $JQ '.data | unique_by(."backup-id") | .[]."backup-id"'
      )

      if [ ${#unique_vm_ids[@]} -eq 0 ]; then
          echo >&2 "Couldn't parse any VM IDs from the PBS API (${STORE}/${NAMESPACE}). Skipping."
          continue
      fi

      unset pbs_snapshot_vm_count_list

      for VM_ID in "${unique_vm_ids[@]}"; do

        snapshot_count_vm_value=$(
            echo "$store_status_json" |
                $JQ "reduce (.data[] | select(.\"backup-id\" == $VM_ID) | .\"backup-id\") as \$i (0;.+=1)"
        )

        pbs_snapshot_vm_count_list+=$(
            printf "pbs_snapshot_vm_count {host=\"%s\", store=\"%s\", namespace=\"%s\", vm_id=%s} %s" \
                "$HOSTNAME" "$STORE" "$NAMESPACE" "$VM_ID" "$snapshot_count_vm_value"
        )

        pbs_snapshot_vm_count_list+=$'\n'
      done

      # fetch number of failed tasks in the last 24 hours
      task_status_json="$(
          $CURL "${PBS_CURL_OPTIONS[@]}" "$PBS_URL/api2/json/nodes/localhost/tasks?store=$STORE&since=${twenty_four_hours_ago}&typefilter=backup&limit=0"
      )"

      if [[ -z "${task_status_json}" ]]; then
          echo >&2 "Couldn't retrieve any task status from the PBS API for store=${STORE}. Skipping."
          continue
      fi

      mapfile -t unique_task_statuses < <(
          echo "$task_status_json" |
              $JQ '.data | unique_by(.status) | .[].status'
      )

      unset pbs_task_status_count_list

      for STATUS in "${unique_task_statuses[@]}"; do

        status_count_value=$(
            echo "$task_status_json" |
                $JQ ".data | group_by (.status)[] | {status: .[0].status, count: length} | select(.status == "$STATUS") | .count"
        )

        pbs_task_status_count_list+=$(
            printf "pbs_task_status_counts {host=\"%s\", store=\"%s\", namespace=\"%s\", status=%s} %d" \
                "$HOSTNAME" "$STORE" "$NAMESPACE" "$STATUS" "$status_count_value"
        )

        pbs_task_status_count_list+=$'\n'
      done

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
# HELP pbs_task_status_counts The number of tasks per status
# TYPE pbs_task_status_counts gauge
# HELP pbs_tasks_error_count The total number of errored tasks in the last 24h
# TYPE pbs_tasks_error_count gauge
# HELP pbs_estimated_full_date The estimated full date for the storage
# TYPE pbs_estimated_full_date gauge
pbs_available {host="$HOSTNAME", store="$STORE"} ${available_value}
pbs_size {host="$HOSTNAME", store="$STORE"} ${size_value}
pbs_used {host="$HOSTNAME", store="$STORE"} ${used_value}
pbs_snapshot_count {host="$HOSTNAME", store="$STORE"} ${store_snapshot_count_value}
pbs_estimated_full_date {host="$HOSTNAME", store="$STORE"} ${estimated_full_date_value}
${pbs_snapshot_vm_count_list}
${pbs_task_status_count_list}
END_HEREDOC
    )

    echo "$backup_stats" | $GZIP |
        $CURL --insecure --silent --fail --show-error \
            --header 'Content-Encoding: gzip' \
            --data-binary @- \
            "${PUSHGATEWAY_URL}"/metrics/job/pbs_exporter/host/"$HOSTNAME"/store/"$STORE"

done

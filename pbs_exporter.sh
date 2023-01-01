#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(curl jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

[[ -z "${PBS_API_TOKEN_NAME}" ]] && echo >&2 "PBS_API_TOKEN_NAME is empty. Aborting" && exit 1
[[ -z "${PBS_API_TOKEN}" ]] && echo >&2 "PBS_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${PBS_URL}" ]] && echo >&2 "PBS_URL is empty. Aborting" && exit 1
[[ -z "${PUSHGATEWAY_URL}" ]] && echo >&2 "PUSHGATEWAY_URL is empty. Aborting" && exit 1

AUTH_HEADER="Authorization: PBSAPIToken=$PBS_API_TOKEN_NAME:$PBS_API_TOKEN"

pbs_json=$(curl -s -q -k -H "$AUTH_HEADER" "$PBS_URL/api2/json/status/datastore-usage")

mapfile -t parsed_stores < <(echo "$pbs_json" | jq -r '.data[].store')

if [ ${#parsed_stores[@]} -eq 0 ]; then
    exit 1
fi

for STORE in "${parsed_stores[@]}"; do

    mapfile -t parsed_backup_stats < <(echo "$pbs_json" | jq -r ".data[] | select(.store==\"$STORE\") | .avail,.total,.used")
    available_value=${parsed_backup_stats[0]}
    size_value=${parsed_backup_stats[1]}
    used_value=${parsed_backup_stats[2]}

    backup_stats=$(
        cat <<END_HEREDOC
# HELP pbs_available The available bytes of the underlying storage. (-1 on error)
# TYPE pbs_available gauge
# HELP pbs_size The size of the underlying storage in bytes. (-1 on error)
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage. (-1 on error)
# TYPE pbs_used gauge
pbs_available {host=\"$HOSTNAME\", store=\"$STORE\"} ${available_value}
pbs_size {host=\"$HOSTNAME\", store=\"$STORE\"} ${size_value}
pbs_used {host=\"$HOSTNAME\", store=\"$STORE\"} ${used_value}
END_HEREDOC
    )

    echo "$backup_stats" | curl --data-binary @- "${PUSHGATEWAY_URL}"/metrics/job/pbs_exporter/host/"$HOSTNAME"/store/"$STORE"

done

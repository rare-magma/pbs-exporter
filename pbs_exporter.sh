#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/pbs_exporter.rc

AUTH_HEADER="Authorization: PBSAPIToken=$PBS_API_TOKEN_NAME:$PBS_API_TOKEN"

pbs_json=$(curl -s -q -k -H "$AUTH_HEADER" "$PBS_URL/api2/json/status/datastore-usage")

mapfile -t parsed_backup_stats < <(echo "$pbs_json" | jq '.data | first | .avail,.total,.used')

if [ ${#parsed_backup_stats[@]} -eq 0 ]; then
    exit 1
fi

available_value=${parsed_backup_stats[0]}
size_value=${parsed_backup_stats[1]}
used_value=${parsed_backup_stats[2]}

backup_stats=$(
    cat <<END_HEREDOC
# HELP pbs_available The available bytes of the underlying storage. (-1 on error)
# TYPE pbs_available gauge
# HELP pbs_size The Size of the underlying storage in bytes. (-1 on error)
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage. (-1 on error)
# TYPE pbs_used gauge
pbs_available ${available_value}
pbs_size ${size_value}
pbs_used ${used_value}
END_HEREDOC
)

echo "$backup_stats" | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/pbs_exporter/host/$HOSTNAME

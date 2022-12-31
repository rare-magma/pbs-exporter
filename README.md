# prometheus-pbs-exporter

Bash script that uploads proxmox backup server info to prometheus's pushgateway.

## Dependencies

- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)

## Install

### With the Makefile

For convenience, you can install this exporter with the following command or follow the process described in the next paragraph.

```
sudo make install
```

### Manually

Copy `pbs_exporter.sh` to `/usr/local/bin` and make it executable.

Copy `pbs_exporter.rc` to `/etc/`, configure it (see the configuration section below) and make it read only.

Copy the systemd unit and timer to `/etc/systemd/system`:

```
sudo cp prometheus-pbs-exporter.* /etc/systemd/system
```

and run the following command to activate the timer:

```
sudo systemctl enable --now prometheus-pbs-exporter.timer
```

It's possible to trigger the execution by running manually:

```
sudo systemctl start prometheus-pbs-exporter.service
```

### Config file

The config file has a few options:

```
PBS_API_TOKEN_NAME='root@pam!prometheus'
PBS_API_TOKEN='123e4567-e89b-12d3-a456-426614174000'
PBS_URL='https://pbs.example.com'
PUSHGATEWAY_URL='https://pushgateway.example.com'
```

- `PBS_API_TOKEN_NAME` should be the value in the "Token name" column in the Proxmox Backup Server user interface - Configuration - Access Control - Api Token page.
- `PBS_API_TOKEN` should be the value shown when the API Token was created.
- `PBS_URL` should be the same https URL as used to access the Proxmox Backup Server user interface
- `PUSHGATEWAY_URL` should be a valid https URL for the [push gateway](https://github.com/prometheus/pushgateway).

### Troubleshooting

Run the script with `bash -x` to get the output of intermediary commands.

## Exported metrics example

```
# HELP pbs_available The available bytes of the underlying storage. (-1 on error)
# TYPE pbs_available gauge
# HELP pbs_size The Size of the underlying storage in bytes. (-1 on error)
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage. (-1 on error)
# TYPE pbs_used gauge
pbs_available 567391420416
pbs_size 691693420544
pbs_used 124302000128
```

## Credits

This project takes inspiration from the following:

- [mad-ady/prometheus-borg-exporter](https://github.com/mad-ady/prometheus-borg-exporter)
- [OVYA/prometheus-borg-exporter](https://github.com/OVYA/prometheus-borg-exporter)

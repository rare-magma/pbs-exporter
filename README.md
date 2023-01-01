# pbs-exporter

Bash script that uploads proxmox backup server API info to prometheus' pushgateway.

## Dependencies

- [bash](https://www.gnu.org/software/bash/)
- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)

## Installation

### With the Makefile

For convenience, you can install this exporter with the following command or follow the process described in the next paragraph.

```
sudo make install
sudoedit /etc/pbs_exporter.conf
```

### Manually

Copy `pbs_exporter.sh` to `/usr/local/bin` and make it executable.

Copy `pbs_exporter.conf` to `/etc/`, configure it (see the configuration section below) and make it read only.

Copy the systemd unit and timer to `/etc/systemd/system`:

```
sudo cp pbs-exporter.* /etc/systemd/system
```

and run the following command to activate the timer:

```
sudo systemctl enable --now pbs-exporter.timer
```

It's possible to trigger the execution by running manually:

```
sudo systemctl start pbs-exporter.service
```

### Config file

The config file has a few options:

```
PBS_API_TOKEN_NAME='user@pam!prometheus'
PBS_API_TOKEN='123e4567-e89b-12d3-a456-426614174000'
PBS_URL='https://pbs.example.com'
PUSHGATEWAY_URL='https://pushgateway.example.com'
```

- `PBS_API_TOKEN_NAME` should be the value in the "Token name" column in the Proxmox Backup Server user interface - Configuration - Access Control - Api Token page.
- `PBS_API_TOKEN` should be the value shown when the API Token was created.
  - This token should have at least the Datastore.Audit access role assigned to it and the path set to /datastore.
- `PBS_URL` should be the same URL as used to access the Proxmox Backup Server user interface
- `PUSHGATEWAY_URL` should be a valid URL for the [push gateway](https://github.com/prometheus/pushgateway).

### Troubleshooting

Check the systemd service logs with `journalctl -ru pbs-exporter.service`
Check the systemd timer info with `systemctl list-timers`

### Relevant documentation

- [PBS API](https://pbs.proxmox.com/docs/api-viewer/index.html)
- [PBS API Tokens](https://pbs.proxmox.com/docs/user-management.html#api-tokens)
- [Prometheus Pushgateway](https://github.com/prometheus/pushgateway/blob/master/README.md)
- [Systemd Timers](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)

## Exported metrics per PBS store

- pbs_available: The available bytes of the underlying storage. (-1 on error)
- pbs_size: The size of the underlying storage in bytes. (-1 on error)
- pbs_used: The used bytes of the underlying storage. (-1 on error)

## Exported metrics example

```
# HELP pbs_available The available bytes of the underlying storage. (-1 on error)
# TYPE pbs_available gauge
# HELP pbs_size The size of the underlying storage in bytes. (-1 on error)
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage. (-1 on error)
# TYPE pbs_used gauge
pbs_available {host="pbs.example.com", store="store1"} -1
pbs_size {host="pbs.example.com", store="store1"} -1
pbs_used {host="pbs.example.com", store="store1"} -1
# HELP pbs_available The available bytes of the underlying storage. (-1 on error)
# TYPE pbs_available gauge
# HELP pbs_size The size of the underlying storage in bytes. (-1 on error)
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage. (-1 on error)
# TYPE pbs_used gauge
pbs_available {host="pbs.example.com", store="store2"} 567317757952
pbs_size {host="pbs.example.com", store="store2"} 691587252224
pbs_used {host="pbs.example.com", store="store2"} 124269494272
# HELP pbs_available The available bytes of the underlying storage. (-1 on error)
# TYPE pbs_available gauge
# HELP pbs_size The size of the underlying storage in bytes. (-1 on error)
# TYPE pbs_size gauge
# HELP pbs_used The used bytes of the underlying storage. (-1 on error)
# TYPE pbs_used gauge
pbs_available {host="pbs.example.com", store="store3"} -1
pbs_size {host="pbs.example.com", store="store3"} -1
pbs_used {host="pbs.example.com", store="store3"} -1
```

## Uninstallation

### With the Makefile

For convenience, you can uninstall this exporter with the following command or follow the process described in the next paragraph.

```
sudo make uninstall
```

### Manually

Run the following command to deactivate the timer:

```
sudo systemctl disable --now pbs-exporter.timer
```

Delete the following files:

```
/usr/local/bin/pbs_exporter.sh
/etc/pbs_exporter.conf
/etc/systemd/system/pbs-exporter.timer
/etc/systemd/system/pbs-exporter.service
```

## Credits

This project takes inspiration from the following:

- [mad-ady/borg-exporter](https://github.com/mad-ady/borg-exporter)
- [OVYA/borg-exporter](https://github.com/OVYA/borg-exporter)

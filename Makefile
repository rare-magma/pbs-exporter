.PHONY: install
install:
	@cp pbs_exporter.sh /usr/local/bin/ \
	&& chmod +x /usr/local/bin/pbs_exporter.sh \
	&& cp -n pbs_exporter.rc /etc/pbs_exporter.rc \
	&& chmod 400 /etc/pbs_exporter.rc \
	&& cp pbs-exporter.timer /etc/systemd/system/ \
	&& cp pbs-exporter.service /etc/systemd/system/ \
	&& echo -n "Edit the config file /etc/pbs_exporter.rc and press [ENTER] when finished "; read _ \
	&& systemctl enable --now pbs-exporter.timer

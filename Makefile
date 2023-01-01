.PHONY: install
install:
	@cp pbs_exporter.sh /usr/local/bin/ \
	&& chmod +x /usr/local/bin/pbs_exporter.sh \
	&& cp --no-clobber pbs_exporter.conf /etc/pbs_exporter.conf \
	&& chmod 400 /etc/pbs_exporter.conf \
	&& cp pbs-exporter.timer /etc/systemd/system/ \
	&& cp pbs-exporter.service /etc/systemd/system/ \
	&& systemctl enable --now pbs-exporter.timer

.PHONY: install-user
install-user:
	@cp pbs_exporter.sh $${HOME}/.local/bin/ \
	&& chmod +x $${HOME}/.local/bin/pbs_exporter.sh \
	&& cp --no-clobber pbs_exporter.conf $${HOME}/.config/pbs_exporter.conf \
	&& chmod 400 $${HOME}/.config/pbs_exporter.conf \
	&& sed -i "s#ExecStart=/usr/local/bin/pbs_exporter.sh#ExecStart=$${HOME}/.local/bin/pbs_exporter.sh#" pbs-exporter.service \
	&& sed -i "s#EnvironmentFile=/etc/pbs_exporter.conf#EnvironmentFile=$${HOME}/.config/pbs_exporter.conf#" pbs-exporter.service \
	&& cp pbs-exporter.timer $${HOME}/.config/systemd/user/ \
	&& cp pbs-exporter.service $${HOME}/.config/systemd/user/ \
	&& systemctl --user enable --now pbs-exporter.timer

.PHONY: uninstall-user
uninstall-user:
	@rm -f $${HOME}/.local/bin/pbs_exporter.sh \
	&& rm -f $${HOME}/.config/pbs_exporter.conf \
	&& systemctl --user disable --now pbs-exporter.timer \
	&& rm -f $${HOME}/.config/.config/systemd/user/pbs-exporter.timer \
	&& rm -f $${HOME}/.config/systemd/user/pbs-exporter.service

.PHONY: install
install:
	@cp pbs_exporter.sh /usr/local/bin/ \
	&& chmod +x /usr/local/bin/pbs_exporter.sh \
	&& cp --no-clobber pbs_exporter.conf /etc/pbs_exporter.conf \
	&& chmod 400 /etc/pbs_exporter.conf \
	&& cp pbs-exporter.timer /etc/systemd/system/ \
	&& cp pbs-exporter.service /etc/systemd/system/ \
	&& systemctl enable --now pbs-exporter.timer

.PHONY: uninstall
uninstall:
	@rm -f /usr/local/bin/pbs_exporter.sh \
	&& rm -f /etc/pbs_exporter.conf \
	&& systemctl disable --now pbs-exporter.timer \
	&& rm -f /etc/systemd/system/pbs-exporter.timer \
	&& rm -f /etc/systemd/system/pbs-exporter.service
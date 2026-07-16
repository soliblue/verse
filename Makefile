.PHONY: bootstrap check seed serve nightly

bootstrap:
	scripts/bootstrap

check:
	python3 -m unittest discover -v
	python3 -m compileall -q db etl server scripts
	for script in scripts/bootstrap scripts/nightjar-preflight scripts/nightjar-agent-run scripts/scheduled-nightjar scripts/install-systemd-user-units; do bash -n "$$script"; done
	python3 -m scripts.check_contracts

seed:
	python3 -m db.seed

serve:
	python3 -m server

nightly:
	scripts/scheduled-nightjar

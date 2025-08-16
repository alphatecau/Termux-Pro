SHELL := /usr/bin/env bash
.ONESHELL:
export ROOT_DIR := $(PWD)
setup: ; bash scripts/update.sh
backup: ; bash scripts/backup.sh
notes: ; bash scripts/notes.sh "Automated note"
sync: ; bash scripts/sync.sh
ssh: ; bash scripts/ssh-setup.sh
smoke: ; bash scripts/smoke.sh

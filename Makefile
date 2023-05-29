prepare:
	bash ./hack/setup-machine.sh
link:
	bash hack/stow-with-backup.sh . ${HOME}

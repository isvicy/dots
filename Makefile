prepare:
	bash ./hack/setup-machine.sh
preview:
	stow . --verbose --target=${HOME} --restow --simulate
link:
	stow . --verbose --target=${HOME} --restow

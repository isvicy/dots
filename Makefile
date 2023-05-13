prepare:
	bash ./hack/prepare.sh
preview:
	stow . --verbose --target=${HOME} --restow --simulate
link:
	stow . --verbose --target=${HOME} --restow

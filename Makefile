fmt:
	echo "===> Format"
	stylua lua/

test:
	echo "===> Test"
	nvim --headless --clean \
		-u tests/configs/tests.vim \
		-c "PlenaryBustedDirectory tests/compile-mode/ {minimal_init = 'tests/configs/tests.vim'}"

setup-ci:
	echo "===> Set Up CI"
	nvim --headless --clean -u tests/configs/ci.vim -c "q"

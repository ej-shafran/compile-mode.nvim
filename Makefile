fmt:
	@echo "===> Format"
	stylua lua/

fmt-check:
	@echo "===> Check Formatting"
	stylua --check lua/

test:
	@echo "===> Test"
	nvim --headless --clean \
		-u spec/configs/tests.vim \
		-c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/configs/tests.vim', sequential = true}"

test-debug:
	@echo "===> Test (w/ Debug Logs)"
	TEST_DEBUG=true nvim --headless --clean \
		-u spec/configs/tests.vim \
		-c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/configs/tests.vim', sequential = true}"

setup-ci:
	@echo "===> Set Up CI"
	nvim --headless --clean -u spec/configs/ci.vim -c "q"

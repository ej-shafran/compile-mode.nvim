FORMAT_FILES := lua/ spec/ plugin/ ftplugin/

fmt:
	@echo "===> Format"
	stylua $(FORMAT_FILES)

fmt-check:
	@echo "===> Check Formatting"
	stylua --check $(FORMAT_FILES)

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

typecheck:
	@echo "===> Typecheck"
	./typecheck.sh

setup-ci:
	@echo "===> Set Up CI"
	nvim --headless --clean -u spec/configs/ci.vim -c "q"

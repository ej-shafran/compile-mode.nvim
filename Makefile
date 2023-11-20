fmt:
	@echo "===> Format"
	stylua lua/

test:
	@echo "===> Test"
	nvim --headless --clean \
		-u tests/configs/tests.vim \
		-c "PlenaryBustedDirectory tests/compile-mode/ {minimal_init = 'tests/configs/tests.vim', sequential = true}"

setup-ci:
	@echo "===> Set Up CI"
	nvim --headless --clean -u tests/configs/ci.vim -c "q"

docs:
	@echo "===> Build Docs"
	./panvimdoc.sh \
		--project-name compile-mode \
		--shift-heading-level-by -1 \
		--scripts-dir ./.panvimdoc/scripts \
		--input-file README.md \
		--vim-version 'NVIM v0.8.0' 

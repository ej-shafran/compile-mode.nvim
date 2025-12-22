#!/usr/bin/env bash
# shellcheck disable=SC2016

VIMRUNTIME="$(
    nvim --headless --clean \
        -u spec/configs/tests.vim \
        -c 'echo $VIMRUNTIME|q' \
        2>&1
)"
PLENARY_PATH="$(
    nvim --headless --clean \
        -u spec/configs/tests.vim \
        -c 'echo fnamemodify(nvim_get_runtime_file("lua/plenary/*.lua", v:false)[0], ":h")|q' \
        2>&1
)"

export VIMRUNTIME PLENARY_PATH

lua-language-server --check . --configpath ./.luarc-ci.json

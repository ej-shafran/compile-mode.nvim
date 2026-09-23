set rtp+=.

set rtp+=../baleia.nvim
set rtp+=../plenary.nvim

lua require("baleia").setup()
runtime! plugin/plenary.vim

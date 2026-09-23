set rtp+=.

set rtp+=../baleia.nvim
set rtp+=../plenary.nvim

" vim-plug
set rtp+=~/.vim/plugged/baleia.nvim
set rtp+=~/.vim/plugged/plenary.nvim

" packer
set rtp+=~/.local/share/nvim/site/pack/packer/start/baleia.nvim
set rtp+=~/.local/share/nvim/site/pack/packer/start/plenary.nvim

" lunarvim
set rtp+=~/.local/share/lunarvim/site/pack/packer/start/baleia.nvim
set rtp+=~/.local/share/lunarvim/site/pack/packer/start/plenary.nvim

" lazy
set rtp+=~/.local/share/nvim/lazy/baleia.nvim
set rtp+=~/.local/share/nvim/lazy/plenary.nvim

" vim.pack
set rtp+=~/.local/share/nvim/site/pack/core/opt/baleia.nvim/
set rtp+=~/.local/share/nvim/site/pack/core/opt/plenary.nvim/

lua require("baleia").setup()
runtime! plugin/plenary.vim

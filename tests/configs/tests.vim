set rtp+=.

set rtp+=../plenary.nvim
set rtp+=../baleia.nvim

" vim-plug
set rtp+=~/.vim/plugged/plenary.nvim
set rtp+=~/.vim/plugged/baleia.nvim

" packer
set rtp+=~/.local/share/nvim/site/pack/packer/start/plenary.nvim
set rtp+=~/.local/share/nvim/site/pack/packer/start/baleia.nvim

" lunarvim
set rtp+=~/.local/share/lunarvim/site/pack/packer/start/plenary.nvim
set rtp+=~/.local/share/lunarvim/site/pack/packer/start/baleia.nvim

" lazy
set rtp+=~/.local/share/nvim/lazy/plenary.nvim
set rtp+=~/.local/share/nvim/lazy/baleia.nvim

set noswapfile

runtime! plugin/plenary.vim
runtime! plugin/baleia.nvim

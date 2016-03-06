if filereadable(expand("~/.config/nvim/ginit.vim"))
    source ~/.config/nvim/ginit.vim
elseif filereadable(expand("~/.gvimrc"))
    source ~/.gvimrc
endif

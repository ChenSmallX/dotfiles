" vim Config for SmallXeon
" ========================

" ---
" Plug: vim-plug
" ==============
call plug#begin('~/.vim/plugged')
" list plugs after this line
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' } 
Plug 'ryanoasis/vim-devicons'
Plug 'jistr/vim-nerdtree-tabs'
Plug 'Xuyuanp/nerdtree-git-plugin'

Plug 'vim-airline/vim-airline' 
Plug 'vim-airline/vim-airline-themes'

"Plug 'edkolev/tmuxline.vim'
"Plug 'luochen1990/rainbow'
"Plug 'treesitter/nvim-ts-rainbow'

" list plugs before this line
" using ':source %' to load config
" and using ':PlugInstall' to install new plugin
" and using ':PlugClean' to remove plugin
call plug#end()

" ---
" general
" =======
set encoding=utf-8
set fileencodings=utf-8,gbk
set t_Co=256
set nocompatible
set confirm
set mouse=a
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undodir=~/.vim/undo//
" remember last position of cursor
set viminfo='10,\"100,:20,%,n~/.viminfo
au BufReadPost * if line("'\"") > 0|if line("'\"") <= line("$")|exe("norm '\"")|else|exe "norm $"|endif|endif

" ---
" UI
" ==
set number
syntax on
set ruler
set novisualbell
set laststatus=2
set showcmd
set showmode
set cursorline
set fillchars=vert:/
set fillchars=stl:/
set fillchars=stlnc:/
set scrolloff=5

" ---
" input
" =====
set showmatch

" ---
" indent
" ======
set cindent
set expandtab
set tabstop=4
set shiftwidth=4
set smarttab
set autoindent
set smartindent

" ---
" search
" ======
set incsearch
set hlsearch
"set ignorecase
set smartcase

" ---
" fold
" ====
set foldenable
set fdm=syntax
set fdm=manual

" ---
" NERDTree
" ========
" Start NERDTree. If a file is specified, move the cursor to its window.
"autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif
" Close when NERDTree is the last window in vim
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
nnoremap <F3> :NERDTreeToggle<CR>
"nnoremap <F3> :NERDTreeMirror<CR>:NERDTreeFocus<CR>
let g:NERDTreeHidden=1
let NERDTreeIgnore = ['\.pyc$', '\.swp', '\.swo', '__pycache__']
"NERDTree git
let g:NERDTreeGitStatusIndicatorMapCustom = {
    \ "Modified"  : "✹",
    \ "Staged"    : "✚",
    \ "Untracked" : "✭",
    \ "Renamed"   : "➜",
    \ "Unmerged"  : "═",
    \ "Deleted"   : "✖",
    \ "Dirty"     : "✗",
    \ "Clean"     : "✔︎",
    \ 'Ignored'   : '☒',
    \ "Unknown"   : "?"
\ }
">> NERDTree-Tabs
let g:nerdtree_tabs_open_on_console_startup=1 "Auto-open Nerdtree-tabs on VIM enter

" ---
" airline
" =======
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme='deus'

" ---
" rainbow
" =======
let g:rainbow_active = 1


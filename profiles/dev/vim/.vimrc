" Ensure config behaves the same however it's loaded
set nocompatible

call plug#begin()

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " Make sure fzf is installed
Plug 'junegunn/fzf.vim' 			    " More fzf commands for vim
Plug 'neoclide/coc.nvim', {'branch': 'release'}     " For Language Server support
Plug 'vim-ruby/vim-ruby'                            " For Facts, Ruby functions, and custom providers
Plug 'lifepillar/vim-solarized8'                    " Solarized theme
Plug 'tpope/vim-endwise'                            " Automatically end structures such as if/end in Ruby
Plug 'airblade/vim-gitgutter'                       " Display git info in the sign column
Plug 'dense-analysis/ale'                           " Auto linting
Plug 'tpope/vim-fugitive'                           " Git bindings

call plug#end()

" Enable file type detection, plugin and indentation
filetype plugin indent on    " required

" Disable mouse
set mouse-=a

" Use UTF-8
set encoding=utf-8

"==========
" Theme
"==========
" Take advantage of modern terms with millions of colors
set termguicolors
set background=dark
autocmd vimenter * ++nested colorscheme solarized8_flat
" Display line numbers
set number
" Highlight current line
set cursorline
" Always show the sign column
set signcolumn=yes
" Enable syntax highlighting
syntax on

" Fuzzy search for pattern in files
nmap <C-p> :Rg<CR>
" Fuzzy search for filenames
nmap <C-f> :Files<CR>

" Code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Coc tab completion
" Use TAB and S-TAB to navigate matches, ENTER to accept
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

let g:coc_global_extensions = ['coc-solargraph']
" Tell Coc where to find nodejs
let g:coc_node_path = trim(system('which node'))

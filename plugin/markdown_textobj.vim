" Markdown link text objects plugin
" Automatically sets up text objects for markdown files

if exists("g:loaded_markdown_textobj")
  finish
endif
let g:loaded_markdown_textobj = 1

" Auto-setup for markdown files
augroup MarkdownTextObjects
  autocmd!
  autocmd FileType markdown call markdown#setup_textobjects()
augroup END
if exists("g:markdown_vim_autoloaded")
  finish
endif
let g:markdown_vim_autoloaded = 1

" Helper function to find the start and end of a markdown link (public for testing)
function! markdown#find_link_bounds()
  let save_cursor = getpos('.')
  let current_line = line('.')
  let current_col = col('.')
  
  " Search backwards for opening bracket, avoiding escaped brackets
  let start_pos = [0, 0]
  let search_line = current_line
  let search_col = current_col
  
  while search_line >= 1
    let line_text = getline(search_line)
    let search_end = search_line == current_line ? search_col - 1 : len(line_text)
    
    for i in range(search_end, 0, -1)
      if line_text[i-1] == '[' && (i == 1 || line_text[i-2] != '\')
        let start_pos = [search_line, i]
        break
      endif
    endfor
    
    if start_pos != [0, 0]
      break
    endif
    let search_line -= 1
  endwhile
  
  if start_pos == [0, 0]
    call setpos('.', save_cursor)
    return {}
  endif
  
  " Find the corresponding closing bracket
  call setpos('.', [0, start_pos[0], start_pos[1], 0])
  let bracket_count = 1
  let end_pos = [0, 0]
  let line_num = start_pos[0]
  let col_num = start_pos[1] + 1
  
  while line_num <= line('$') && bracket_count > 0
    let line_text = getline(line_num)
    let max_col = len(line_text)
    
    while col_num <= max_col && bracket_count > 0
      let char = line_text[col_num - 1]
      if char == '[' && (col_num == 1 || line_text[col_num - 2] != '\')
        let bracket_count += 1
      elseif char == ']' && (col_num == 1 || line_text[col_num - 2] != '\')
        let bracket_count -= 1
        if bracket_count == 0
          let end_pos = [line_num, col_num]
        endif
      endif
      let col_num += 1
    endwhile
    
    if bracket_count > 0
      let line_num += 1
      let col_num = 1
    endif
  endwhile
  
  if end_pos == [0, 0]
    call setpos('.', save_cursor)
    return {}
  endif
  
  " Check if cursor is within the brackets
  let cursor_before_start = (current_line < start_pos[0]) || (current_line == start_pos[0] && current_col <= start_pos[1])
  let cursor_after_end = (current_line > end_pos[0]) || (current_line == end_pos[0] && current_col >= end_pos[1])
  if cursor_before_start || cursor_after_end
    call setpos('.', save_cursor)
    return {}
  endif
  
  let result = {}
  let result.text_start = start_pos
  let result.text_end = end_pos
  
  " Now check what follows the closing bracket
  let next_line = end_pos[0]
  let next_col = end_pos[1] + 1
  let next_text = ''
  
  if next_col <= len(getline(next_line))
    let next_text = getline(next_line)[next_col - 1:]
  elseif next_line < line('$')
    let next_text = getline(next_line + 1)
  endif
  
  " Check for inline link (...) 
  if next_text =~ '^('
    let paren_start = [next_line, next_col]
    let paren_count = 1
    let paren_end = [0, 0]
    let p_line = next_line
    let p_col = next_col + 1
    
    while p_line <= line('$') && paren_count > 0
      let line_text = getline(p_line)
      let max_col = len(line_text)
      
      while p_col <= max_col && paren_count > 0
        let char = line_text[p_col - 1]
        if char == '('
          let paren_count += 1
        elseif char == ')'
          let paren_count -= 1
          if paren_count == 0
            let paren_end = [p_line, p_col]
          endif
        endif
        let p_col += 1
      endwhile
      
      if paren_count > 0
        let p_line += 1
        let p_col = 1
      endif
    endwhile
    
    if paren_end != [0, 0]
      let result.url_start = paren_start
      let result.url_end = paren_end
      let result.inline_start = start_pos
      let result.inline_end = paren_end
      let result.type = 'inline'
    endif
  " Check for reference link [...][...]
  elseif next_text =~ '^\]\s*\['
    let ref_match = matchstr(next_text, '^\]\s*\[')
    let ref_start_col = next_col + len(ref_match) - 1
    let ref_start = [next_line, ref_start_col]
    
    " Find closing bracket for reference
    let ref_count = 1
    let ref_end = [0, 0]
    let r_line = next_line
    let r_col = ref_start_col + 1
    
    while r_line <= line('$') && ref_count > 0
      let line_text = getline(r_line)
      let max_col = len(line_text)
      
      while r_col <= max_col && ref_count > 0
        let char = line_text[r_col - 1]
        if char == '['
          let ref_count += 1
        elseif char == ']'
          let ref_count -= 1
          if ref_count == 0
            let ref_end = [r_line, r_col]
          endif
        endif
        let r_col += 1
      endwhile
      
      if ref_count > 0
        let r_line += 1
        let r_col = 1
      endif
    endwhile
    
    if ref_end != [0, 0]
      let result.ref_start = ref_start
      let result.ref_end = ref_end
      let result.inline_start = start_pos
      let result.inline_end = ref_end
      let result.type = 'reference'
    endif
  endif
  
  call setpos('.', save_cursor)
  return result
endfunction

" Text object for link text (inside [...])
function! markdown#link_text_textobj(type)
  let bounds = markdown#find_link_bounds()
  if empty(bounds)
    return
  endif
  
  if a:type == 'i'
    " Inner text object - select inside the brackets
    let start_pos = [bounds.text_start[0], bounds.text_start[1] + 1]
    let end_pos = [bounds.text_end[0], bounds.text_end[1] - 1]
  else
    " Around text object - select including the brackets
    let start_pos = [bounds.text_start[0], bounds.text_start[1]]
    let end_pos = [bounds.text_end[0], bounds.text_end[1]]
  endif
  
  " Escape any mode and enter visual mode
  execute "normal! \<Esc>"
  call cursor(start_pos[0], start_pos[1])
  normal! v
  call cursor(end_pos[0], end_pos[1])
endfunction

" Text object for link URL (inside (...) or reference)
function! markdown#link_url_textobj(type)
  let bounds = markdown#find_link_bounds()
  if empty(bounds)
    return
  endif
  
  let start_pos = []
  let end_pos = []
  
  if has_key(bounds, 'url_start') && has_key(bounds, 'url_end')
    " Inline link URL
    if a:type == 'i'
      " Inner - select inside the parentheses
      let start_pos = [bounds.url_start[0], bounds.url_start[1] + 1]
      let end_pos = [bounds.url_end[0], bounds.url_end[1] - 1]
    else
      " Around - select including the parentheses
      let start_pos = [bounds.url_start[0], bounds.url_start[1]]
      let end_pos = [bounds.url_end[0], bounds.url_end[1]]
    endif
  elseif has_key(bounds, 'ref_start') && has_key(bounds, 'ref_end')
    " Reference link
    if a:type == 'i'
      " Inner - select inside the reference brackets
      let start_pos = [bounds.ref_start[0], bounds.ref_start[1] + 1]
      let end_pos = [bounds.ref_end[0], bounds.ref_end[1] - 1]
    else
      " Around - select including the reference brackets
      let start_pos = [bounds.ref_start[0], bounds.ref_start[1]]
      let end_pos = [bounds.ref_end[0], bounds.ref_end[1]]
    endif
  endif
  
  if !empty(start_pos) && !empty(end_pos)
    execute "normal! \<Esc>"
    call cursor(start_pos[0], start_pos[1])
    normal! v
    call cursor(end_pos[0], end_pos[1])
  endif
endfunction

" Text object for the inline portion of the link
function! markdown#link_inline_textobj(type)
  let bounds = markdown#find_link_bounds()
  if empty(bounds)
    return
  endif
  
  if has_key(bounds, 'inline_start') && has_key(bounds, 'inline_end')
    let start_pos = [bounds.inline_start[0], bounds.inline_start[1]]
    let end_pos = [bounds.inline_end[0], bounds.inline_end[1]]
    
    execute "normal! \<Esc>"
    call cursor(start_pos[0], start_pos[1])
    normal! v
    call cursor(end_pos[0], end_pos[1])
  endif
endfunction

" Set up the text object mappings
function! markdown#setup_textobjects()
  " Map for link text
  onoremap <buffer> <silent> ilt :<C-u>call markdown#link_text_textobj('i')<CR>
  onoremap <buffer> <silent> alt :<C-u>call markdown#link_text_textobj('a')<CR>
  vnoremap <buffer> <silent> ilt :<C-u>call markdown#link_text_textobj('i')<CR>
  vnoremap <buffer> <silent> alt :<C-u>call markdown#link_text_textobj('a')<CR>
  
  " Map for link URL
  onoremap <buffer> <silent> ilu :<C-u>call markdown#link_url_textobj('i')<CR>
  onoremap <buffer> <silent> alu :<C-u>call markdown#link_url_textobj('a')<CR>
  vnoremap <buffer> <silent> ilu :<C-u>call markdown#link_url_textobj('i')<CR>
  vnoremap <buffer> <silent> alu :<C-u>call markdown#link_url_textobj('a')<CR>
  
  " Map for inline portion
  onoremap <buffer> <silent> ill :<C-u>call markdown#link_inline_textobj('i')<CR>
  onoremap <buffer> <silent> all :<C-u>call markdown#link_inline_textobj('a')<CR>
  vnoremap <buffer> <silent> ill :<C-u>call markdown#link_inline_textobj('i')<CR>
  vnoremap <buffer> <silent> all :<C-u>call markdown#link_inline_textobj('a')<CR>
endfunction
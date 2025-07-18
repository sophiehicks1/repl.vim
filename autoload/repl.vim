if exists("g:repl_vim_autoloaded")
  finish
endif
let g:repl_vim_autoloaded = 1

if !exists("g:repl_jobs")
  let g:repl_jobs = {}
  let g:repl_buffers = {}
  let g:repl_commands = {}
  let g:repl_opbinds = {}
  let g:repl_linebinds = {}
  let g:repl_quit_seqs = {}
endif

" terminal wrappers to normalize nvim/vim behaviour
function! s:return_to_previous_window()
  execute "normal! p"
endfunction

function! s:start_job(name)
  let l:buffer = buffer_number('.')
  let l:job_id = 0
  if has('nvim')
    new
    let l:job_id = termopen(g:repl_commands[a:name])
  else
    let l:job_id = term_start(g:repl_commands[a:name])
  endif
  " if the buffer has changed, then we shifted to the repl window and need to
  " back
  if l:buffer != buffer_number('.')
    call s:return_to_previous_window()
  endif
  return l:job_id
endfunction

function! s:send_to_job(name, content)
  let l:term_id = g:repl_jobs[a:name]
  if has('nvim')
    call chansend(l:term_id, a:content)
  else
    call term_sendkeys(l:term_id, a:content)
  endif
endfunction

function! s:job_status(name)
  let l:term_id = g:repl_jobs[a:name]
  if has('nvim')
    if jobwait([l:term_id], 0)[0] == -1
      return "running"
    else
      return "finished"
    endif
  else
    return term_getstatus(l:term_id)
  endif
endfunction

" run the repl command as a terminal in a new buffer (without stealing focus)
function! s:run_command(name, opts)
  if !repl#is_running(a:name)
    if a:opts.cmd ==# ''
      echoerr "REPL ".a:name." is not running. Please provide a command."
    endif
    if has_key(a:opts, 'quit')
      let g:repl_quit_seqs[a:name] = a:opts['quit']
    endif
    let g:repl_commands[a:name] = a:opts.cmd
    let g:repl_jobs[a:name] = s:start_job(a:name)
    let g:repl_buffers[a:name] = bufnr('%')
  endif
endfunction

" Operator implementation to send lines to a repl
function! s:operator(name, type)
  let sel_save = &selection
  let &selection = "inclusive"
  let reg_save = @@
  try
    if a:type ==# 'v' || a:type ==# 'V' || a:type ==# ''
	    silent exe "normal! gvy"
    elseif a:type ==# 'line'
	    silent exe "normal! '[V']y"
    elseif type(a:type) ==# v:t_number
      silent exe "normal! ".a:type."yy"
    else
	    silent exe "normal! `[v`]y"
    endif
    let lines = split(@@, "\n")
    call repl#send(a:name, lines)
  finally
	  let &selection = sel_save
	  let @@ = reg_save
  endtry
endfunction

function! s:operator_name(name)
  return "REPL_" . a:name . "_operator"
endfunction

function! s:operator_exists(name)
  return exists(s:operator_name(a:name))
endfunction

function! s:make_operator(name)
  execute "function! " . s:operator_name(a:name) . "(type) \n call s:operator('" 
        \ . a:name . "', a:type)\n endfunction"
endfunction

function! s:create_operator(name)
  if !s:operator_exists(a:name)
    call s:make_operator(a:name)
  endif
endfunction

" Functions to bind the operator to the chosen keybinds
function! s:bind_operator(name, opts)
  let l:opbind = ''
  if has_key(a:opts, 'opbind') && a:opts.opbind !=# ''
    let l:opbind = a:opts.opbind
    let g:repl_opbinds[a:name] = a:opts.opbind
  elseif has_key(g:repl_opbinds, a:name)
    let l:opbind = g:repl_opbinds[a:name]
  end
  if l:opbind !=# ''
    execute "nnoremap <buffer> <silent> " . l:opbind . " :set operatorfunc=" . s:operator_name(a:name) . "<cr>g@"
    execute "vnoremap <buffer> <silent> " . l:opbind . " :<c-u>call " . s:operator_name(a:name) . "(visualmode())<cr>"
  endif
endfunction

function! s:bind_linewise(name, opts)
  let l:binding = ''
  if has_key(a:opts, 'linebind') && a:opts.linebind !=# ''
    let l:binding = a:opts.linebind
    let g:repl_linebinds[a:name] = a:opts.linebind
  elseif has_key(g:repl_linebinds, a:name)
    let l:binding = g:repl_linebinds[a:name]
  end
  if l:binding !=# ''
    execute "nnoremap <buffer> <silent> " . l:binding . " :call " . s:operator_name(a:name) . "(v:count1)<CR>"
  endif
endfunction

" main repl management functions
function! repl#start(name, opts)
  call s:create_operator(a:name)
  call s:bind_operator(a:name, a:opts)
  call s:bind_linewise(a:name, a:opts)
  call s:run_command(a:name, a:opts)
endfunction

function! repl#kill(name)
  if has_key(g:repl_quit_seqs, a:name) && g:repl_quit_seqs[a:name] != ''
    call s:send_to_job(a:name, g:repl_quit_seqs[a:name])
  else
    exec "bw! ".g:repl_buffers[a:name]
  endif
  call remove(g:repl_jobs, a:name)
endfunction

function! repl#is_running(name)
  if has_key(g:repl_jobs, a:name)
    let status = s:job_status(a:name)
    return status ==# "running" || status ==# "normal"
  else
    return v:false
  endif
endfunction

function! repl#send(name, msg_lines)
  for l:line in a:msg_lines
    call s:send_to_job(a:name], l:line . "\<cr>")
    redraw!
  endfor
endfunction

function! repl#restart(name)
  call repl#kill(a:name)
  call repl#start(a:name, {})
endfunction

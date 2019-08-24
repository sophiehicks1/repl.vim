if exists("g:repl_vim_autoloaded")
  finish
endif
let g:repl_vim_autoloaded = 1

if !exists("g:repl_jobs")
  let g:repl_jobs = {}
  let g:repl_commands = {}
  let g:repl_bindings = {}
endif

function! repl#handler(channel, msg)
  let buffer_name = '__REPL__'
  for l:name in keys(g:repl_jobs)
    if job_getchannel(g:repl_jobs[l:name]) ==# a:channel
      let buffer_name = s:buffer_name(l:name)
    endif
  endfor
  call show#append(buffer_name, [a:msg])
endfunction

function! s:buffer_name(name)
  return "__".a:name."__"
endfunction

function! s:start_job(name)
  let opts = {"callback": "repl#handler", 'mode': 'nl'}
  call show#show(s:buffer_name(a:name), [])
  return job_start(g:repl_commands[a:name], opts)
endfunction

function! repl#kill(name)
  call job_stop(g:repl_jobs[a:name])
  call remove(g:repl_jobs, a:name)
endfunction

function! repl#restart(name)
  call repl#kill(a:name)
  call repl#start(a:name)
endfunction

function! repl#status(name)
  if has_key(g:repl_jobs, a:name)
    return job_status(g:repl_jobs[a:name])
  else
    return "NA"
  endif
endfunction

function! s:send(name, msg_lines)
  let channel = job_getchannel(g:repl_jobs[a:name])
  for l:msg in a:msg_lines
    call ch_sendraw(channel, l:msg . "")
  endfor
endfunction

function! s:operator_exists(name)
  return exists(s:operator_name(a:name))
endfunction

function! s:operator(name, type)
  let saved_register = @@
  try
    if a:type ==# 'char'
      normal! `[v`]y
    else
      normal! `<v`>y
    endif
    let lines = split(@@, "\n")
  finally
    let @@ = saved_register
  endtry
  call s:send(a:name, lines)
endfunction

function! s:operator_name(name)
  return "REPL_" . a:name . "_operator"
endfunction

function! s:make_operator(name)
  execute "function! " . s:operator_name(a:name) . "(type) \n call s:operator('" 
        \. a:name . "', a:type) \n endfunction"
endfunction

function! repl#start(name, opts)
  if repl#status(a:name) !=# 'run'
    if a:opts.cmd ==# ''
      echoerr "REPL ".a:name." is not running. Please provide a command."
    endif
    let g:repl_commands[a:name] = a:opts.cmd
    let g:repl_jobs[a:name] = s:start_job(a:name)
  endif
  if !s:operator_exists(a:name)
    call s:make_operator(a:name)
  endif
  let l:binding = ''
  if a:opts.binding !=# ''
    let l:binding = a:opts.binding
    let g:repl_bindings[a:name] = a:opts.binding
  elseif has_key(g:repl_bindings, a:name)
    let l:binding = g:repl_bindings[a:name]
  else
    echoerr "No default binding exists for REPL " . a:name . ". Please provide a binding"
  end
  execute "nnoremap <buffer> " . l:binding . " :set operatorfunc=" . s:operator_name(a:name) . "<cr>g@"
  execute "vnoremap <buffer> " . l:binding . " :<c-u>call " . s:operator_name(a:name) . "(visualmode())<cr>"
endfunction

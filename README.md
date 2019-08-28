# `repl.vim`

`repl.vim` is a utility plugin for easily creating repl plugins in vim. It provides a handful of
functions.

***`repl#start(name, opts)`***

This starts a terminal running `a:opts.cmd` and creates some buffer-local bindings (bound to the
`a:opts.binding` argument) for sending text/commands/code/whatever to that job.

That's pretty abstract, so here's an example. If you run the following in an `R` buffer:

```{.vimscript}
call repl#start('r', {
      \ 'opbind': 'cp',
      \ 'linebind': 'cpp',
      \ 'cmd': 'R --no-save --no-readline --interactive',
      \ 'quit': 'q()'})
```

... it will start an interactive R session in the background, and open a buffer `__r__` for the
output of that session. Then, if you select a few lines of R code using visual mode, and hit `cp`
(the binding we passed into the function) it will send those lines of R code into that interactive R
session and update the results in the `__r__` buffer.

The `cp` binding it creates works just like vim's built in operators (like 'd', 'c', 'y', etc.). You
can use it in visual mode to send the selected text, or in normal mode as an operator with a motion
(e.g. `cpap` to send the current paragraph). The `linebind` argument is used to create a matching
normal mode mapping that accepts a count (like 'yy', 'cc', etc.).

Once you've started that repl in one buffer, you can connect to the same session in other buffers
using the same command. Since the repl is already running, this time you can omit the `'binding'`
and `'cmd'` options.

```{.vimscript}
call repl#start('r', {})
```

One option is to wrap this in a function that starts the repl, and then sets up an autocommand to
automatically connect all other relevent buffers to the same repl. That way, you only have to
connect to a repl once, and that repl will then be available in all subsequent files of the same
file type. Here's what that looks like:

```{.vimscript}
function! s:rconnect()
  call repl#start('r', {
        \ 'opbind': 'cp',
        \ 'linebind': 'cpp',
        \ 'cmd': 'R --no-save --no-readline --interactive'
        \ 'quit': 'q()'})
  autocmd! BufNewFile *.R call repl#start('r', {})
endfunction

command! -buffer Connect call <SID>rconnect()
```

***`repl#send(name, msg_lines)`***

Send `a:msg_lines` to the named repl, using `term_sendkeys`. `a:msg_lines` should be a list of
strings that will be interpretted using vimscript keybinding syntax (e.g. `'\<C-c>'` means sending
Ctrl-c). Carriage returns will automatically be appended.

***`repl#kill(name)`***

This kills the job by sending the `'quit'` option to the terminal.

***`repl#restart(name)`***

Self explanatory. This kills the background repl job and restarts it as a new job.


## Example usage:

As you can probably guess, I wrote this to use with R. Here's my `ftplugin/r.vim` to show you how I
use it:

```{.vim}
function! s:rconnect()
  call repl#start('r', {
        \ 'opbind': 'cp',
        \ 'linebind': 'cpp',
        \ 'quit': 'q()',
        \ 'cmd': 'R --no-save --no-readline --interactive'})
  autocmd! BufNewFile *.R call repl#start('r', {})
endfunction

command! -buffer Connect call <SID>rconnect()
command! -buffer Restart call repl#restart('r')
```

All the options are optional, although obviously if you don't set `cmd` at least the first time it
won't know what command to run.

## Dependencies

This only works if you've compiled vim with the `terminal` option. You can check for this by running
`:version` and looking for `+terminal`.

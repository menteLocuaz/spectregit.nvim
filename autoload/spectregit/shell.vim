if exists('g:autoloaded_spectregit_shell') | finish | endif
let g:autoloaded_spectregit_shell = 1

let s:save_cpo = &cpo
set cpo&vim

function! spectregit#shell#winshell() abort
  return has('win32') && &shellcmdflag !~# '^-'
endfunction

function! spectregit#shell#shellesc(arg) abort
  if type(a:arg) == type([])
    return join(map(copy(a:arg), 'spectregit#shell#shellesc(v:val)'))
  elseif a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  elseif spectregit#shell#winshell()
    return '"' . spectregit#core#gsub(spectregit#core#gsub(a:arg, '"', '""'), '\%', '"%"') . '"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! spectregit#shell#SystemError(cmd, ...) abort
  let cmd = type(a:cmd) == type([]) ? spectregit#shell#shellesc(a:cmd) : a:cmd
  try
    if &shellredir ==# '>' && &shell =~# 'sh\|cmd'
      let shellredir = &shellredir
      if &shell =~# 'csh'
        set shellredir=>&
      else
        set shellredir=>%s\ 2>&1
      endif
    endif
    if exists('+guioptions') && &guioptions =~# '!'
      let guioptions = &guioptions
      set guioptions-=!
    endif
    let out = call('system', [cmd] + a:000)
    return [out, v:shell_error]
  catch /^Vim\%((\a\+)\)\=:E484:/
    let opts = ['shell', 'shellcmdflag', 'shellredir', 'shellquote', 'shellxquote', 'shellxescape', 'shellslash']
    call filter(opts, 'exists("+".v:val) && !empty(eval("&".v:val))')
    call map(opts, 'v:val."=".eval("&".v:val)')
    call spectregit#core#Throw('failed to run `' . cmd . '` with ' . join(opts, ' '))
  finally
    if exists('shellredir')
      let &shellredir = shellredir
    endif
    if exists('guioptions')
      let &guioptions = guioptions
    endif
  endtry
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

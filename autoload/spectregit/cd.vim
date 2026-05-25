if exists('g:autoloaded_spectregit_cd') | finish | endif
let g:autoloaded_spectregit_cd = 1

function! spectregit#cd#Complete(A, L, P) abort
  return filter(fugitive#CompletePath(a:A), 'v:val =~# "/$"')
endfunction

function! spectregit#cd#Cd(path) abort
  exe spectregit#core#VersionCheck()
  let path = substitute(a:path, '^:/:\=\|^:(\%(top\|top,literal\|literal,top\|literal\))', '', '')
  if path !~# '^/\|^\a\+:\|^\.\.\=\%(/\|$\)'
    let dir = spectregit#core#Dir()
    exe spectregit#core#DirCheck(dir)
    let path = (empty(spectregit#core#Tree(dir)) ? dir : spectregit#core#Tree(dir)) . '/' . path
  endif
  return 'cd ' . spectregit#core#fnameescape(spectregit#core#VimSlash(path))
endfunction

function! spectregit#cd#Lcd(path) abort
  exe spectregit#core#VersionCheck()
  let path = substitute(a:path, '^:/:\=\|^:(\%(top\|top,literal\|literal,top\|literal\))', '', '')
  if path !~# '^/\|^\a\+:\|^\.\.\=\%(/\|$\)'
    let dir = spectregit#core#Dir()
    exe spectregit#core#DirCheck(dir)
    let path = (empty(spectregit#core#Tree(dir)) ? dir : spectregit#core#Tree(dir)) . '/' . path
  endif
  return 'lcd ' . spectregit#core#fnameescape(spectregit#core#VimSlash(path))
endfunction

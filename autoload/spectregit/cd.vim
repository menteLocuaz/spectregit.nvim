if exists('g:autoloaded_spectregit_cd') | finish | endif
let g:autoloaded_spectregit_cd = 1

function! spectregit#cd#Complete(A, L, P) abort
  return filter(spectregit#complete#Path(a:A), 'v:val =~# "/$"')
endfunction

function! spectregit#cd#Cd(path, ...) abort
  exe spectregit#core#VersionCheck()
  let path = substitute(a:path, '^:/:\=\|^:(\%(top\|top,literal\|literal,top\|literal\))', '', '')
  if path !~# '^/\|^\a\+:\|^\.\.\=\%(/\|$\)'
    let dir = spectregit#core#Dir()
    exe spectregit#core#DirCheck(dir)
    let path = (empty(spectregit#core#Tree(dir)) ? dir : spectregit#core#Tree(dir)) . '/' . path
  endif
  return (a:0 && a:1 ? 'lcd ' : 'cd ') . fnameescape(spectregit#core#VimSlash(path))
endfunction

function! spectregit#cd#Lcd(path) abort
  return spectregit#cd#Cd(a:path, 1)
endfunction

if exists('g:autoloaded_spectregit_path') | finish | endif
let g:autoloaded_spectregit_path = 1

function! spectregit#path#Parse(url) abort
  if empty(a:url)
    return ['', '']
  endif
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  let rev = commit . file ==# '/.git/index' ? ':' : (!empty(dir) && commit =~# '^.$' ? ':' : '') . commit . substitute(file, '^/', ':', '')
  return [rev, dir]
endfunction

function! spectregit#path#Real(url) abort
  if empty(a:url)
    return ''
  endif
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  if len(dir)
    let tree = spectregit#core#Tree(dir)
    return spectregit#core#VimSlash((len(tree) ? tree : FugitiveGitDir(dir)) . file)
  endif
  let pre = substitute(matchstr(a:url, '^\a\a\+\ze:'), '^.', '\u&', '')
  if len(pre) && pre !=? 'fugitive' && exists('*' . pre . 'Real')
    let url = {pre}Real(a:url)
  else
    let url = fnamemodify(a:url, ':p' . (a:url =~# '[\/]$' ? '' : ':s?[\/]$??'))
  endif
  return spectregit#core#VimSlash(empty(url) ? a:url : url)
endfunction

function! spectregit#path#Path(url, ...) abort
  if empty(a:url)
    return ''
  endif
  let repo = call('spectregit#core#Dir', a:000[1:-1])
  let dir_s = FugitiveFind('.git/', repo)
  let tree = FugitiveFind(':/', repo)
  if !a:0
    return spectregit#path#Real(a:url)
  elseif a:1 =~# '\.$'
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    let cwd = getcwd()
    let lead = ''
    while spectregit#core#cpath(tree . '/', (cwd . '/')[0 : len(tree)])
      if spectregit#core#cpath(cwd . '/', path[0 : len(cwd)])
        if strpart(path, len(cwd) + 1) =~# '^\.git\%(/\|$\)'
          break
        endif
        let lead = './'
        break
      endif
      let cwd = fnamemodify(cwd, ':h')
    endwhile
    if !len(lead)
      let path = FugitiveFind(':(top)', repo)
      if len(path) && path[-1:] !=# '/'
        let path .= '/'
      endif
      let lead = path
    endif
    return spectregit#core#Slash(lead . path[strlen(lead) : -1])
  elseif a:1 =~# '^\.\/\|\.[\/]$'
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    let cwd = getcwd() . '/'
    if spectregit#core#cpath(path[0 : len(cwd) - 1], cwd[0 : -2])
      return '.' . path[len(cwd) - 1 : -1]
    endif
    return spectregit#core#Slash(path)
  elseif a:1 =~# '^/\|^:\|^\.\.'
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    return spectregit#core#Slash(a:1 =~# '^/' ? path : '.')
  elseif a:1 =~# '^:\d\=:'
    let commit = matchstr(a:1, '^\zs:\d\=\ze:')
    let file = matchstr(a:1, '^:\d\=:\zs.*')
    if len(file)
      return FugitiveFind(commit . ':' . file, repo)
    endif
    return ''
  endif
  if a:1 ==# ':(top)'
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    if spectregit#core#cpath(tree . '/', path[0 : len(tree)])
      return path[len(tree) : -1]
    endif
    return path
  endif
  if a:1 ==# ':(top,literal)' || a:1 ==# ':(literal,top)'
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    if spectregit#core#cpath(tree . '/', path[0 : len(tree)])
      return path[len(tree) : -1]
    endif
    return path
  endif
  if a:1 =~# '^:\%(:[^:]\|$\)'
    let commit = matchstr(a:1, '^:.*')
    let file = matchstr(spectregit#core#Slash(spectregit#path#Real(a:url)), '^' . tree . '/\zs.*')
    return FugitiveFind(commit . file, repo)
  endif
  if a:1 =~# '^:\.'
    let cwd = getcwd()
    if len(tree) && !spectregit#core#cpath(tree . '/', cwd[0 : len(tree)])
      let cwd = tree
    endif
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    lead = ''
    while spectregit#core#cpath(cwd . '/', path[0 : len(cwd)])
      if strpart(path, len(cwd) + 1) =~# '^\.git\%(/\|$\)'
        break
      endif
      return ':(top,literal)' . path
    endwhile
    return spectregit#core#Slash(a:1 . path[len(cwd) : -1])
  endif
  return spectregit#core#Slash(spectregit#path#Real(a:url))
endfunction

function! spectregit#path#UrlEncode(str) abort
  return substitute(a:str, '[%#?[:cntrl:]]', '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! spectregit#path#DirUrlPrefix(dir) abort
  let gd = spectregit#core#Dir(a:dir)
  return 'fugitive://' . (gd =~# '^[^/]' ? '/' : '') . spectregit#path#UrlEncode(gd) . '//'
endfunction

function! spectregit#path#Generate(object, ...) abort
  let dir = a:0 ? a:1 : spectregit#core#Dir()
  let f = fugitive#Find(a:object, dir)
  if !empty(f)
    return f
  elseif a:object ==# ':/'
    return len(dir) ? spectregit#core#VimSlash(spectregit#path#DirUrlPrefix(dir) . '0') : '.'
  endif
  let file = matchstr(a:object, '^\%(:\d:\|[^:]*:\)\=\zs.*')
  return empty(file) ? '' : fnamemodify(spectregit#core#VimSlash(file), ':p')
endfunction

function! spectregit#path#Join(prefix, str) abort
  if a:prefix =~# '://'
    return a:prefix . spectregit#path#UrlEncode(a:str)
  else
    return a:prefix . a:str
  endif
endfunction

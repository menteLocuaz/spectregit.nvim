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

function! spectregit#path#Find(object, ...) abort
  if type(a:object) == type(0)
    let name = bufname(a:object)
    return spectregit#core#VimSlash(name =~# '^$\|^/\|^\a\+:' ? name : getcwd() . '/' . name)
  elseif a:object =~# '^[~$]'
    let prefix = matchstr(a:object, '^[~$]\i*')
    let owner = expand(prefix)
    return spectregit#core#VimSlash(FugitiveVimPath((len(owner) ? owner : prefix) . strpart(a:object, len(prefix))))
  endif
  let rev = spectregit#core#Slash(a:object)
  if rev =~# '^\a\+://' && rev !~# '^fugitive:'
    return rev
  elseif rev =~# '^$\|^/\|^\%(\a\a\+:\).*\%(//\|::\)' . (has('win32') ? '\|^\a:/' : '')
    return spectregit#core#VimSlash(a:object)
  elseif rev =~# '^\.\.\=\%(/\|$\)'
    return spectregit#core#VimSlash(simplify(getcwd() . '/' . a:object))
  endif
  let dir = call('FugitiveGitDir', a:000)
  if empty(dir)
    let file = matchstr(a:object, '^\%(:\d:\|[^:]*:\)\zs\%(\.\.\=$\|\.\.\=/.*\|/.*\|\w:/.*\)')
    let dir = FugitiveExtractGitDir(file)
    if empty(dir)
      return ''
    endif
  endif
  let tree = FugitiveWorkTree(dir)
  let urlprefix = spectregit#path#DirUrlPrefix(dir)
  let base = len(tree) ? tree : urlprefix . '0'
  if rev ==# '.git'
    let f = len(tree) && len(getftype(tree . '/.git')) ? tree . '/.git' : dir
  elseif rev =~# '^\.git/'
    let f = strpart(rev, 5)
    let fdir = simplify(FugitiveActualDir(dir) . '/')
    let cdir = simplify(FugitiveCommonDir(dir) . '/')
    if f =~# '^\.\./\.\.\%(/\|$\)'
      let f = simplify(len(tree) ? tree . f[2:-1] : fdir . f)
    elseif f =~# '^\.\.\%(/\|$\)'
      let f = spectregit#path#Join(base, f[2:-1])
    elseif cdir !=# fdir && (
          \ f =~# '^\%(config\|hooks\|info\|logs/refs\|objects\|refs\|worktrees\)\%(/\|$\)' ||
          \ f !~# '^\%(index$\|index\.lock$\|\w*MSG$\|\w*HEAD$\|logs/\w*HEAD$\|logs$\|rebase-\w\+\)\%(/\|$\)' &&
          \ getftime(fdir . f) < 0 && getftime(cdir . f) >= 0)
      let f = simplify(cdir . f)
    else
      let f = simplify(fdir . f)
    endif
  elseif rev ==# ':/'
    let f = tree
  elseif rev =~# '^\.\%(/\|$\)'
    let f = spectregit#path#Join(base, rev[1:-1])
  elseif rev =~# '^::\%(/\|\a\+\:\)'
    let f = rev[2:-1]
  elseif rev =~# '^::\.\.\=\%(/\|$\)'
    let f = simplify(getcwd() . '/' . rev[2:-1])
  elseif rev =~# '^::'
    let f = spectregit#path#Join(base, '/' . rev[2:-1])
  elseif rev =~# '^:\%([0-3]:\)\=\.\.\=\%(/\|$\)\|^:[0-3]:\%(/\|\a\+:\)'
    let f = rev =~# '^:\%([0-3]:\)\=\.' ? simplify(getcwd() . '/' . matchstr(rev, '\..*')) : rev[3:-1]
    if spectregit#core#cpath(base . '/', (f . '/')[0 : len(base)])
      let f = spectregit#path#Join(urlprefix, +matchstr(rev, '^:\zs\d\ze:') . '/' . strpart(f, len(base) + 1))
    else
      let altdir = FugitiveExtractGitDir(f)
      if len(altdir) && !spectregit#core#cpath(dir, altdir)
        return spectregit#path#Find(a:object, altdir)
      endif
    endif
  elseif rev =~# '^:[0-3]:'
    let f = spectregit#path#Join(urlprefix, rev[1] . '/' . rev[3:-1])
  elseif rev ==# ':'
    let f = urlprefix
  elseif rev =~# '^:(\%(top\|top,literal\|literal,top\|literal\))'
    let f = matchstr(rev, ')\zs.*')
    if f=~# '^\.\.\=\%(/\|$\)'
      let f = simplify(getcwd() . '/' . f)
    elseif f !~# '^/\|^\%(\a\a\+:\).*\%(//\|::\)' . (has('win32') ? '\|^\a:/' : '')
      let f = spectregit#path#Join(base, '/' . f)
    endif
  elseif rev =~# '^:/\@!'
    let f = spectregit#path#Join(urlprefix, '0/' . rev[1:-1])
  else
    if !exists('f')
      let commit = matchstr(rev, '^\%([^:.-]\|\.\.[^/:]\)[^:]*\|^:.*')
      let file = substitute(matchstr(rev, '^\%([^:.-]\|\.\.[^/:]\)[^:]*\zs:.*'), '^:', '/', '')
      if file =~# '^/\.\.\=\%(/\|$\)\|^//\|^/\a\+:'
        let file = file =~# '^/\.' ? simplify(getcwd() . file) : file[1:-1]
        if spectregit#core#cpath(base . '/', (file . '/')[0 : len(base)])
          let file = '/' . strpart(file, len(base) + 1)
        else
          let altdir = FugitiveExtractGitDir(file)
          if len(altdir) && !spectregit#core#cpath(dir, altdir)
            return spectregit#path#Find(a:object, altdir)
          endif
          return file
        endif
      endif
      let commits = split(commit, '\.\.\.-\@!', 1)
      if len(commits) == 2
        call map(commits, 'empty(v:val) ? "@" : v:val')
        let commit = matchstr(spectregit#core#ChompDefault('', [dir, 'merge-base'] + commits + ['--']), '\<[0-9a-f]\{40,\}\>')
      endif
      if commit !~# '^[0-9a-f]\{40,\}$\|^$'
        let commit = matchstr(spectregit#core#ChompDefault('', [dir, 'rev-parse', '--verify', commit . (len(file) ? '^{}' : ''), '--']), '\<[0-9a-f]\{40,\}\>')
        if empty(commit) && len(file)
          let commit = repeat('0', 40)
        endif
      endif
      if len(commit)
        let f = spectregit#path#Join(urlprefix, commit . file)
      else
        let f = spectregit#path#Join(base, '/' . substitute(rev, '^:/:\=\|^[^:]\+:', '', ''))
      endif
    endif
  endif
  return spectregit#core#VimSlash(f)
endfunction

function! spectregit#path#Generate(object, ...) abort
  let dir = a:0 ? a:1 : spectregit#core#Dir()
  let f = spectregit#path#Find(a:object, dir)
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

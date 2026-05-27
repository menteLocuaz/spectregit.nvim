if exists('g:autoloaded_spectregit_path') | finish | endif
let g:autoloaded_spectregit_path = 1

let s:save_cpo = &cpo
set cpo&vim

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
    return spectregit#core#VimSlash((len(tree) ? tree : spectregit#core#Dir(dir)) . file)
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
  let dir_s = spectregit#path#Find('.git/', repo)
  let tree = spectregit#path#Find(':/', repo)
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
      let path = spectregit#path#Find(':(top)', repo)
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
      return spectregit#path#Find(commit . ':' . file, repo)
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
    return spectregit#path#Find(commit . file, repo)
  endif
  if a:1 =~# '^:\.'
    let cwd = getcwd()
    if len(tree) && !spectregit#core#cpath(tree . '/', cwd[0 : len(tree)])
      let cwd = tree
    endif
    let path = spectregit#core#Slash(spectregit#path#Real(a:url))
    let lead = ''
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
    return spectregit#core#VimSlash(spectregit#core#VimPath((len(owner) ? owner : prefix) . strpart(a:object, len(prefix))))
  endif
  let rev = spectregit#core#Slash(a:object)
  if rev =~# '^\a\+://' && rev !~# '^fugitive:'
    return rev
  elseif rev =~# '^$\|^/\|^\%(\a\a\+:\).*\%(//\|::\)' . (has('win32') ? '\|^\a:/' : '')
    return spectregit#core#VimSlash(a:object)
  elseif rev =~# '^\.\.\=\%(/\|$\)'
    return spectregit#core#VimSlash(simplify(getcwd() . '/' . a:object))
  endif
  let dir = call('spectregit#core#Dir', a:000)
  if empty(dir)
    let file = matchstr(a:object, '^\%(:\d:\|[^:]*:\)\zs\%(\.\.\=$\|\.\.\=/.*\|/.*\|\w:/.*\)')
    let dir = spectregit#core#ExtractGitDir(file)
    if empty(dir)
      return ''
    endif
  endif
  let tree = spectregit#core#Tree(dir)
  let urlprefix = spectregit#path#DirUrlPrefix(dir)
  let base = len(tree) ? tree : urlprefix . '0'
  if rev ==# '.git'
    let f = len(tree) && len(getftype(tree . '/.git')) ? tree . '/.git' : dir
  elseif rev =~# '^\.git/'
    let f = strpart(rev, 5)
    let fdir = simplify(spectregit#core#ActualDir(dir) . '/')
    let cdir = simplify(spectregit#core#CommonDir(dir) . '/')
    if f =~# '^\.\./\.\.\%(/\|$\)'
      let f = simplify(len(tree) ? tree . f[2:-1] : fdir . f)
    elseif f =~# '^\.\.\%(/\|$\)'
      let f = spectregit#path#Join(base, f[2:-1])
    elseif cdir !=# fdir && (f =~# '^\%(config\|hooks\|info\|logs/refs\|objects\|refs\|worktrees\)\%(/\|$\)' || f !~# '^\%(index$\|index\.lock$\|\w*MSG$\|\w*HEAD$\|logs/\w*HEAD$\|logs$\|rebase-\w\+\)\%(/\|$\)' && getftime(fdir . f) < 0 && getftime(cdir . f) >= 0)
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
      let altdir = spectregit#core#ExtractGitDir(f)
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
          let altdir = spectregit#core#ExtractGitDir(file)
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

let s:trees = {}
let s:indexes = {}
function! s:TreeInfo(dir, commit) abort
  let key = spectregit#core#Dir(a:dir)
  if a:commit =~# '^:\=[0-3]$'
    let index = get(s:indexes, key, [])
    let newftime = getftime(spectregit#path#Find('.git/index', a:dir))
    if get(index, 0, -2) < newftime
      let [lines, exec_error] = spectregit#core#LinesError([a:dir, 'ls-files', '--stage', '--'])
      let s:indexes[key] = [newftime, {'0': {}, '1': {}, '2': {}, '3': {}}]
      if exec_error
        return [{}, -1]
      endif
      for line in lines
        let [info, filename] = split(line, "\t")
        let [mode, sha, stage] = split(info, '\s\+')
        let s:indexes[key][1][stage][filename] = [newftime, mode, 'blob', sha, -2]
        while filename =~# '/'
          let filename = substitute(filename, '/[^/]*$', '', '')
          let s:indexes[key][1][stage][filename] = [newftime, '040000', 'tree', '', 0]
        endwhile
      endfor
    endif
    return [get(s:indexes[key][1], a:commit[-1:-1], {}), newftime]
  elseif a:commit =~# '^\x\{40,\}$'
    if !has_key(s:trees, key)
      let s:trees[key] = {}
    endif
    if !has_key(s:trees[key], a:commit)
      let ftime = spectregit#core#ChompDefault('', [a:dir, 'log', '-1', '--pretty=format:%ct', a:commit, '--'])
      if empty(ftime)
        let s:trees[key][a:commit] = [{}, -1]
        return s:trees[key][a:commit]
      endif
      let s:trees[key][a:commit] = [{}, +ftime]
      let [lines, exec_error] = spectregit#core#LinesError([a:dir, 'ls-tree', '-rtl', '--full-name', a:commit, '--'])
      if exec_error
        return s:trees[key][a:commit]
      endif
      for line in lines
        let [info, filename] = split(line, "\t")
        let [mode, type, sha, size] = split(info, '\s\+')
        let s:trees[key][a:commit][0][filename] = [+ftime, mode, type, sha, +size, filename]
      endfor
    endif
    return s:trees[key][a:commit]
  endif
  return [{}, -1]
endfunction

function! s:PathInfo(url) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  if empty(dir) || !get(g:, 'fugitive_file_api', 1)
    return [-1, '000000', '', '', -1]
  endif
  let path = substitute(file[1:-1], '/*$', '', '')
  let [tree, ftime] = s:TreeInfo(dir, commit)
  let entry = empty(path) ? [ftime, '040000', 'tree', '', -1] : get(tree, path, [])
  if empty(entry) || file =~# '/$' && entry[2] !=# 'tree'
    return [-1, '000000', '', '', -1]
  else
    return entry
  endif
endfunction

function! spectregit#path#getftime(url) abort
  return s:PathInfo(a:url)[0]
endfunction

function! spectregit#path#getfsize(url) abort
  let entry = s:PathInfo(a:url)
  if entry[4] == -2 && entry[2] ==# 'blob' && len(entry[3])
    let dir = spectregit#core#DirCommitFile(a:url)[0]
    let entry[4] = +spectregit#core#ChompDefault(-1, [dir, 'cat-file', '-s', entry[3]])
  endif
  return entry[4]
endfunction

function! spectregit#path#getftype(url) abort
  return get({'tree': 'dir', 'blob': 'file'}, s:PathInfo(a:url)[2], '')
endfunction

function! spectregit#path#filereadable(url) abort
  return s:PathInfo(a:url)[2] ==# 'blob'
endfunction

function! spectregit#path#filewritable(url) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  if commit !~# '^\d$' || !filewritable(spectregit#path#Find('.git/index', dir))
    return 0
  endif
  return s:PathInfo(a:url)[2] ==# 'blob' ? 1 : 2
endfunction

function! spectregit#path#isdirectory(url) abort
  return s:PathInfo(a:url)[2] ==# 'tree'
endfunction

function! spectregit#path#getfperm(url) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  let perm = getfperm(dir)
  let fperm = s:PathInfo(a:url)[1]
  if fperm ==# '040000'
    let fperm = '000755'
  endif
  if fperm !~# '[15]'
    let perm = tr(perm, 'x', '-')
  endif
  if fperm !~# '[45]$'
    let perm = tr(perm, 'rw', '--')
  endif
  return perm
endfunction

function! spectregit#path#setfperm(url, perm) abort
  throw 'fugitive: setfperm() not supported for fugitive:// URLs'
endfunction

function! spectregit#path#simplify(url) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  if empty(dir)
    return ''
  elseif empty(commit)
    return spectregit#core#VimSlash(spectregit#path#DirUrlPrefix(simplify(spectregit#core#Dir(dir))))
  endif
  if file =~# '/\.\.\%(/\|$\)'
    let tree = spectregit#core#Tree(dir)
    if len(tree)
      let path = simplify(tree . file)
      if strpart(path . '/', 0, len(tree) + 1) !=# tree . '/'
        return spectregit#core#VimSlash(path)
      endif
    endif
  endif
  return spectregit#core#VimSlash(spectregit#path#Join(spectregit#path#DirUrlPrefix(simplify(spectregit#core#Dir(dir))), commit . simplify(file)))
endfunction

function! spectregit#path#resolve(url) abort
  let url = spectregit#path#simplify(a:url)
  if url =~? '^fugitive:'
    return url
  else
    return resolve(url)
  endif
endfunction

function! s:BlobTemp(url) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  let entry = s:PathInfo(a:url)
  if empty(dir) || entry[2] !=# 'blob' || empty(entry[3])
    return ''
  endif
  let temp = tempname()
  let [err, status] = spectregit#core#StdoutToFile(temp, [dir, 'cat-file', 'blob', entry[3]])
  if status
    return ''
  endif
  return temp
endfunction

function! spectregit#path#readfile(url, ...) abort
  let entry = s:PathInfo(a:url)
  if entry[2] !=# 'blob'
    return []
  endif
  let temp = s:BlobTemp(a:url)
  if empty(temp)
    return []
  endif
  try
    return call('readfile', [temp] + a:000)
  finally
    call delete(temp)
  endtry
endfunction

function! spectregit#path#writefile(lines, url, ...) abort
  let url = type(a:url) ==# type('') ? a:url : ''
  let [dir, commit, file] = spectregit#core#DirCommitFile(url)
  let entry = s:PathInfo(url)
  if commit =~# '^\d$' && entry[2] !=# 'tree'
    let temp = tempname()
    if a:0 && a:1 =~# 'a' && entry[2] ==# 'blob'
      call writefile(spectregit#path#readfile(url, 'b'), temp, 'b')
    endif
    call writefile(a:lines, temp, a:0 ? a:1 : '')
    let [err, status] = spectregit#core#SystemError(spectregit#git#ShellCommand([dir, 'hash-object', '-w', '--path=' . file[1:-1], temp]))
    let sha = matchstr(err, '^\x\{40,\}')
    if !status && len(sha)
      let [err, status] = spectregit#core#SystemError(spectregit#git#ShellCommand([dir, 'update-index', '--add', '--cacheinfo', (empty(entry[1]) || entry[1] ==# '000000' ? '100644' : entry[1]) . ',' . sha . ',' . file[1:-1]]))
    endif
    call delete(temp)
    if !status
      call spectregit#core#DoAutocmdChanged(dir)
      return 0
    endif
  endif
  return -1
endfunction

function! spectregit#path#glob(url, ...) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  if empty(dir)
    return []
  endif
  let [tree, ftime] = s:TreeInfo(dir, commit)
  let pattern = spectregit#core#gsub(file[1:-1], '[[\]*?]', '\\&')
  let matches = filter(keys(tree), 'v:val =~# "^" . pattern')
  return map(matches, 'spectregit#path#Join(spectregit#path#DirUrlPrefix(dir), commit . "/" . v:val)')
endfunction

function! spectregit#path#delete(url, ...) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  if commit =~# '^\d$'
    let [err, status] = spectregit#core#SystemError(spectregit#git#ShellCommand([dir, 'update-index', '--force-remove', '--', file[1:-1]]))
    if !status
      call spectregit#core#DoAutocmdChanged(dir)
      return 0
    endif
  endif
  return -1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

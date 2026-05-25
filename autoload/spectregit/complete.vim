if exists('g:autoloaded_spectregit_complete') | finish | endif
let g:autoloaded_spectregit_complete = 1

let s:merge_heads = ['MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD']

function! spectregit#complete#FilterEscape(items, ...) abort
  let items = copy(a:items)
  call map(items, 'fnameescape(v:val)')
  if !a:0 || type(a:1) != type('')
    let match = ''
  else
    let esc = spectregit#core#fnameescape('')
    let match = substitute(a:1, '^[+>]\|\\\@<![' . substitute(esc, '\\', '', '') . ']', '\\&', 'g')
  endif
  let cmp = spectregit#core#FileIgnoreCase(1) ? '==?' : '==#'
  return filter(items, 'strpart(v:val, 0, strlen(match)) ' . cmp . ' match')
endfunction

function! spectregit#complete#GlobComplete(lead, pattern, ...) abort
  if a:lead ==# '/'
    return []
  else
    let results = glob(substitute(a:lead . a:pattern, '[\{}]', '\\&', 'g'), a:0 ? a:1 : 0, 1)
  endif
  call map(results, 'v:val !~# "/$" && isdirectory(v:val) ? v:val."/" : v:val')
  call map(results, 'v:val[ strlen(a:lead) : -1 ]')
  return results
endfunction

function! spectregit#complete#CompletePath(base, ...) abort
  let dir = a:0 == 1 ? a:1 : a:0 >= 3 ? a:3 : spectregit#core#Dir()
  let stripped = matchstr(a:base, '^\%(:/:\=\|:(top)\|:(top,literal)\|:(literal,top)\)')
  let base = strpart(a:base, len(stripped))
  if len(stripped) || a:0 < 4
    let root = spectregit#core#Tree(dir)
  else
    let root = a:4
  endif
  if root !=# '/' && len(root)
    let root .= '/'
  endif
  if empty(stripped)
    let stripped = matchstr(a:base, '^\%(:(literal)\|:\)')
    let base = strpart(a:base, len(stripped))
  endif
  if base =~# '^\.git/' && len(dir)
    let pattern = spectregit#core#gsub(base[5:-1], '/', '*&').'*'
    let fdir = FugitiveFind('.git/', dir)
    let matches = spectregit#complete#GlobComplete(fdir, pattern)
    let cdir = FugitiveFind('.git/refs', dir)[0 : -5]
    if len(cdir) && spectregit#core#cpath(fdir) !=# spectregit#core#cpath(cdir)
      call extend(matches, spectregit#complete#GlobComplete(cdir, pattern))
    endif
    call spectregit#core#Uniq(matches)
    call map(matches, "'.git/' . v:val")
  elseif base =~# '^\~/'
    let matches = map(spectregit#complete#GlobComplete(expand('~/'), base[2:-1] . '*'), '"~/" . v:val')
  elseif a:base =~# '^/\|^\a\+:\|^\.\.\=/'
    let matches = spectregit#complete#GlobComplete('', base . '*')
  elseif len(root)
    let matches = spectregit#complete#GlobComplete(root, spectregit#core#gsub(base, '/', '*&').'*')
  else
    let matches = []
  endif
  call map(matches, 'spectregit#core#fnameescape(spectregit#core#Slash(stripped . v:val))')
  return matches
endfunction

function! spectregit#complete#PathComplete(...) abort
  return call('spectregit#complete#CompletePath', a:000)
endfunction

function! spectregit#complete#Heads(dir) abort
  if empty(a:dir)
    return []
  endif
  let dir = FugitiveFind('.git/', a:dir)
  return sort(filter(['HEAD', 'FETCH_HEAD', 'ORIG_HEAD'] + s:merge_heads, 'filereadable(dir . v:val)')) +
        \ sort(spectregit#core#LinesError([a:dir, 'rev-parse', '--symbolic', '--branches', '--tags', '--remotes'])[0])
endfunction

function! spectregit#complete#Object(base, ...) abort
  let dir = a:0 == 1 ? a:1 : a:0 >= 3 ? a:3 : spectregit#core#Dir()
  let tree = spectregit#core#Tree(dir)
  let cwd = getcwd()
  let subdir = ''
  if len(tree) && spectregit#core#cpath(tree . '/', cwd[0 : len(tree)])
    let subdir = strpart(cwd, len(tree) + 1) . '/'
  endif
  let base = s:Expand(a:base)

  if a:base =~# '^!\d*$' && base !~# '^!'
    return [base]
  elseif base =~# '^\.\=/\|^:(' || base !~# ':'
    let results = []
    if base =~# '^refs/'
      let cdir = FugitiveFind('.git/refs', dir)[0 : -5]
      let results += map(spectregit#complete#GlobComplete(cdir, base . '*'), 'spectregit#core#Slash(v:val)')
      call map(results, 'spectregit#core#fnameescape(v:val)')
    elseif base !~# '^\.\=/\|^:('
      let heads = spectregit#complete#Heads(dir)
      if filereadable(FugitiveFind('.git/refs/stash', dir))
        let heads += ["stash"]
        let heads += sort(spectregit#core#LinesError(["stash","list","--pretty=format:%gd"], dir)[0])
      endif
      let results += spectregit#complete#FilterEscape(heads, fnameescape(base))
    endif
    let results += a:0 == 1 || a:0 >= 3 ? spectregit#complete#CompletePath(base, 0, '', dir, a:0 >= 4 ? a:4 : tree) : spectregit#complete#CompletePath(base)
    return results

  elseif base =~# '^:'
    let entries = spectregit#core#LinesError(['ls-files','--stage'], dir)[0]
    if base =~# ':\./'
      call map(entries, 'substitute(v:val, "\\M\t\\zs" . subdir, "./", "")')
    endif
    call map(entries, 'spectregit#core#sub(v:val, ".*(\\d)\\t(.*)", ":\\1:\\2")')
    if base !~# '^:[0-3]\%(:\|$\)'
      call filter(entries, 'v:val[1] == "0"')
      call map(entries, 'v:val[2:-1]')
    endif

  else
    let parent = matchstr(base, '.*[:/]')
    let entries = spectregit#core#LinesError(['ls-tree', substitute(parent, ':\zs\./', '\=subdir', '')], dir)[0]
    call map(entries, 'spectregit#core#sub(v:val, "^04.*\\zs$", "/")')
    call map(entries, 'parent . spectregit#core#sub(v:val, ".*\t", "")')
  endif
  return spectregit#complete#FilterEscape(entries, fnameescape(base))
endfunction

function! s:Expand(rev, ...) abort
  if a:rev =~# '^>' && spectregit#core#Slash(@%) =~# '^fugitive://' && empty(spectregit#core#DirCommitFile(@%)[1])
    return spectregit#core#Slash(@%)
  elseif a:rev =~# '^>\=:[0-3]$'
    let file = len(expand('%')) ? a:rev[-2:-1] . ':%' : '%'
  elseif a:rev =~# '^>\%(:\=/\)\=$'
    let file = '%'
  elseif a:rev =~# '^>[> ]\@!' && @% !~# '^fugitive:' && spectregit#core#Slash(@%) =~# '://\|^$'
    let file = '%'
  elseif a:rev ==# '>:'
    let file = empty(spectregit#core#DirCommitFile(@%)[0]) ? ':0:%' : '%'
  elseif a:rev =~# '^>[> ]\@!'
    let rev = (a:rev =~# '^>[~^]' ? '!' : '') . a:rev[1:-1]
    let prefix = matchstr(rev, '^\%(\\.\|{[^{}]*}\|[^:]\)*')
    if prefix !=# rev
      let file = rev
    else
      let file = prefix . ':'
      if rev =~# '^:[0-3]'
        let file .= '%'
      endif
    endif
  elseif a:rev =~# '^>'
    return a:rev
  elseif a:rev ==# ''
    let file = empty(spectregit#core#DirCommitFile(@%)[0]) ? ':0:%' : '%'
  elseif a:rev ==# '%'
    let file = spectregit#core#Slash(@%)
  elseif a:rev ==# '#'
    let file = spectregit#core#Slash(@#)
  elseif a:rev =~# '^[~^]'
    let file = '@' . a:rev
  else
    return a:rev
  endif
  if exists('file')
    if file =~# '^fugitive://'
      return spectregit#core#fnameescape(file)
    elseif file =~# '^/\|^\a\+:\|^$'
      return spectregit#core#fnameescape(file)
    elseif file ==# '%'
      return spectregit#core#fnameescape(spectregit#core#Slash(@%))
    else
      if !a:0
        let dir = spectregit#core#Dir()
      else
        let dir = a:1
      endif
      let prefix = FugitiveFind(!empty(dir) ? ':(top)' : ':.')
      if file =~# '^:[0-3]'
        let rev = file[0:1]
        let file = rev . prefix[0:-2]
      else
        let file = prefix . file
      endif
      return spectregit#core#fnameescape(FugitiveFind(file, dir))
    endif
  endif
  return a:rev
endfunction

function! spectregit#complete#Sub(subcommand, A, L, P, ...) abort
  let pre = strpart(a:L, 0, a:P)
  if pre =~# ' -- '
    return spectregit#complete#CompletePath(a:A)
  elseif a:A =~# '^-' || a:A is# 0
    return spectregit#complete#FilterEscape(split(spectregit#core#ChompDefault('', [a:subcommand, '--git-completion-helper']), ' '), a:A)
  elseif !a:0
    return spectregit#complete#Object(a:A, spectregit#core#Dir())
  elseif type(a:1) == type(function('tr'))
    return call(a:1, [a:A, a:L, a:P] + (a:0 > 1 ? a:2 : []))
  else
    return spectregit#complete#FilterEscape(a:1, a:A)
  endif
endfunction

function! spectregit#complete#Revision(A, L, P, ...) abort
  return spectregit#complete#FilterEscape(spectregit#complete#Heads(a:0 ? a:1 : spectregit#core#Dir()), a:A)
endfunction

function! spectregit#complete#Remote(A, L, P, ...) abort
  let dir = a:0 ? a:1 : spectregit#core#Dir()
  let remote = matchstr(a:L, '\u\w*[! ] *.\{-\}\s\@<=\zs[^-[:space:]]\S*\ze ')
  if !empty(remote)
    let matches = spectregit#core#LinesError([dir, 'ls-remote', remote])[0]
    call filter(matches, 'v:val =~# "\t" && v:val !~# "{"')
    call map(matches, 'spectregit#core#sub(v:val, "^.*\t%(refs/%(heads/|tags/)=)=", "")')
  else
    let matches = spectregit#core#LinesError([dir, 'remote'])[0]
  endif
  return spectregit#complete#FilterEscape(matches, a:A)
endfunction

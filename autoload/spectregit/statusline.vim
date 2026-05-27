if exists('g:autoloaded_spectregit_statusline') | finish | endif
let g:autoloaded_spectregit_statusline = 1

let s:dirty_cache = {}

function! spectregit#statusline#Get(...) abort
  let dir = spectregit#core#Dir(bufnr(''))
  if empty(dir)
    return ''
  endif
  let status = ''
  let commit = spectregit#core#DirCommitFile(@%)[1]
  if len(commit)
    let status .= ':' . commit[0:6]
  endif
  let status .= '('.spectregit#git#Head(7, dir).')'

  let tree = spectregit#core#Tree(dir)
  if type(tree) == type('') && len(tree)
    let index = spectregit#path#Find('.git/index', dir)
    let ftime = getftime(index)
    let cache_key = index . ftime
    if has_key(s:dirty_cache, cache_key)
      let changed = s:dirty_cache[cache_key]
    else
      let changed = len(spectregit#core#TreeChomp(['diff', '--name-status', 'HEAD', '--', tree]))
      let s:dirty_cache = {cache_key : changed}
    endif
    if changed
      let status .= '*'
    endif
  endif

  return '[Git'.status.']'
endfunction

function! spectregit#statusline#ClearCaches() abort
  let s:dirty_cache = {}
endfunction

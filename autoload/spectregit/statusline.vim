if exists('g:autoloaded_spectregit_statusline') | finish | endif
let g:autoloaded_spectregit_statusline = 1

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
  
  " Add simple status indicator (dirty check)
  let changed = len(spectregit#core#TreeChomp(['diff', '--name-status', 'HEAD', '--', dir]))
  if changed
    let status .= '*'
  endif
  
  return '[Git'.status.']'
endfunction

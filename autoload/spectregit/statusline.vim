if exists('g:autoloaded_spectregit_statusline') | finish | endif
let g:autoloaded_spectregit_statusline = 1

function! spectregit#statusline#Get(...) abort
  let dir = FugitiveGitDir(bufnr(''))
  if empty(dir)
    return ''
  endif
  let status = ''
  let commit = spectregit#core#DirCommitFile(@%)[1]
  if len(commit)
    let status .= ':' . commit[0:6]
  endif
  let status .= '('.FugitiveHead(7, dir).')'
  return '[Git'.status.']'
endfunction

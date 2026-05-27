if exists('g:autoloaded_spectregit_branch') | finish | endif
let g:autoloaded_spectregit_branch = 1

function! spectregit#branch#Create(branch_name) abort
  let dir = spectregit#core#Dir()
  if empty(dir)
    return 'echoerr "fugitive: not a Git repository"'
  endif
  
  if empty(a:branch_name)
    return 'echoerr "fugitive: branch name required"'
  endif

  let result = spectregit#git#Execute([dir, 'checkout', '-b', a:branch_name])
  if result.exit_status != 0
    return 'echoerr "fugitive: failed to create branch: ' . join(result.stderr, ' ') . '"'
  endif
  
  return 'echo "Switched to new branch: ' . a:branch_name . '"'
endfunction

function! spectregit#branch#Complete(A, L, P) abort
  return spectregit#complete#Revision(a:A, a:L, a:P)
endfunction

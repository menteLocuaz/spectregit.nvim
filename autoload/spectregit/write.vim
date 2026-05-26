if exists('g:autoloaded_spectregit_write') | finish | endif
let g:autoloaded_spectregit_write = 1

" Section: :Gwrite, :Gwq

function! s:ChompStderr(...) abort
  let r = call('fugitive#Execute', a:000)
  return !r.exit_status ? '' : len(r.stderr) > 1 ? spectregit#core#JoinChomp(r.stderr) : 'unknown Git error' . string(r)
endfunction

function! spectregit#write#WriteCommand(line1, line2, range, bang, mods, arg, ...) abort
  exe spectregit#core#VersionCheck()
  if spectregit#core#cpath(expand('%:p'), fugitive#Find('.git/COMMIT_EDITMSG')) && empty(a:arg)
    return (empty($GIT_INDEX_FILE) ? 'write|bdelete' : 'wq') . (a:bang ? '!' : '')
  elseif get(b:, 'fugitive_type', '') ==# 'index' && empty(a:arg)
    return 'Git commit'
  elseif &buftype ==# 'nowrite' && getline(4) =~# '^[+-]\{3\} '
    return 'echoerr ' . string('fugitive: :Gwrite from :Git diff has been removed in favor of :Git add --edit')
  endif
  let mytab = tabpagenr()
  let mybufnr = bufnr('')
  let args = spectregit#core#ArgSplit(a:arg)
  let after = ''
  if get(args, 0) =~# '^+'
    let after = '|' . remove(args, 0)[1:-1]
  endif
  try
    let file = len(args) ? spectregit#path#Generate(fugitive#Expand(join(args, ' '))) : fugitive#Real(@%)
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
  if empty(file)
    return 'echoerr '.string('fugitive: cannot determine file path')
  endif
  if file =~# '^fugitive:'
    return 'write' . (a:bang ? '! ' : ' ') . spectregit#core#fnameescape(file)
  endif
  exe spectregit#core#DirCheck()
  let always_permitted = spectregit#core#cpath(fugitive#Real(@%), file) && empty(spectregit#core#DirCommitFile(@%)[1])
  if !always_permitted && !a:bang && (len(spectregit#core#TreeChomp('diff', '--name-status', 'HEAD', '--', file)) || len(spectregit#core#TreeChomp('ls-files', '--others', '--', file)))
    let v:errmsg = 'fugitive: file has uncommitted changes (use ! to override)'
    return 'echoerr v:errmsg'
  endif
  let treebufnr = 0
  for nr in range(1,bufnr('$'))
    if fnamemodify(bufname(nr),':p') ==# file
      let treebufnr = nr
    endif
  endfor
  if treebufnr > 0 && treebufnr != bufnr('')
    let temp = tempname()
    silent execute 'keepalt %write '.temp
    for tab in [mytab] + range(1,tabpagenr('$'))
      for winnr in range(1,tabpagewinnr(tab,'$'))
        if tabpagebuflist(tab)[winnr-1] == treebufnr
          execute 'tabnext '.tab
          if winnr != winnr()
            execute winnr.'wincmd w'
            let restorewinnr = 1
          endif
          try
            let lnum = line('.')
            let last = line('$')
            silent execute '$read '.temp
            silent execute '1,'.last.'delete_'
            silent write!
            silent execute lnum
            diffupdate
            let did = 1
          finally
            if exists('restorewinnr')
              wincmd p
            endif
            execute 'tabnext '.mytab
          endtry
          break
        endif
      endfor
    endfor
    if !exists('did')
      call writefile(readfile(temp,'b'),file,'b')
    endif
  else
    execute 'write! '.spectregit#core#fnameescape(file)
  endif
  let message = s:ChompStderr(['add'] + (a:bang ? ['--force'] : []) + ['--', file])
  if len(message)
    let v:errmsg = 'fugitive: '.message
    return 'echoerr v:errmsg'
  endif
  if spectregit#core#cpath(fugitive#Real(@%), file) && spectregit#core#DirCommitFile(@%)[1] =~# '^\d$'
    setlocal nomodified
  endif
  let one = fugitive#Find(':1:'.file)
  let two = fugitive#Find(':2:'.file)
  let three = fugitive#Find(':3:'.file)
  for nr in range(1,bufnr('$'))
    let name = fnamemodify(bufname(nr), ':p')
    if bufloaded(nr) && !getbufvar(nr,'&modified') && (name ==# one || name ==# two || name ==# three)
      execute nr.'bdelete'
    endif
  endfor
  unlet! restorewinnr
  let zero = fugitive#Find(':0:'.file)
  exe spectregit#core#DoAutocmd('BufWritePost ' . spectregit#core#fnameescape(zero))
  for tab in range(1,tabpagenr('$'))
    for winnr in range(1,tabpagewinnr(tab,'$'))
      let bufnr = tabpagebuflist(tab)[winnr-1]
      let bufname = fnamemodify(bufname(bufnr), ':p')
      if bufname ==# zero && bufnr != mybufnr
        execute 'tabnext '.tab
        if winnr != winnr()
          execute winnr.'wincmd w'
          let restorewinnr = 1
        endif
        try
          let lnum = line('.')
          let last = line('$')
          silent execute '$read '.spectregit#core#fnameescape(file)
          silent execute '1,'.last.'delete_'
          silent execute lnum
          setlocal nomodified
          diffupdate
        finally
          if exists('restorewinnr')
            wincmd p
          endif
          execute 'tabnext '.mytab
        endtry
        break
      endif
    endfor
  endfor
  call fugitive#DidChange()
  return 'checktime' . after
endfunction

function! spectregit#write#WqCommand(...) abort
  let bang = a:4 ? '!' : ''
  if spectregit#core#cpath(expand('%:p'), fugitive#Find('.git/COMMIT_EDITMSG'))
    return 'wq'.bang
  endif
  let result = call('spectregit#write#WriteCommand', a:000)
  if result =~# '^\%(write\|wq\|echoerr\)'
    return spectregit#core#sub(result,'^write','wq')
  else
    return result.'|quit'.bang
  endif
endfunction

if exists('g:autoloaded_spectregit_autocmd') | finish | endif
let g:autoloaded_spectregit_autocmd = 1

let s:blobdirs = {}

function! s:DoAutocmd(...) abort
  return call('spectregit#core#DoAutocmd', a:000)
endfunction

function! s:Map(mode, lhs, rhs, ...) abort
  return call('spectregit#maps#Map', [a:mode, a:lhs, a:rhs] + a:000)
endfunction

function! s:DirRev(url) abort
  let [dir, commit, file] = spectregit#core#DirCommitFile(a:url)
  return [dir, commit . file ==# '/.git/index' ? ':' : (!empty(dir) && commit =~# '^.$' ? ':' : '') . commit . substitute(file, '^/', ':', '')]
endfunction

function! s:InitializeBuffer(dir) abort
  let b:git_dir = spectregit#core#Dir(a:dir)
endfunction

function! s:ReplaceCmd(cmd) abort
  let temp = tempname()
  let [err, exec_error] = spectregit#core#StdoutToFile(temp, a:cmd)
  if exec_error
    throw 'fugitive: ' . (len(err) ? substitute(err, "\n$", '', '') : 'unknown error running ' . string(a:cmd))
  endif
  setlocal noswapfile
  silent exe 'lockmarks keepalt noautocmd 0read ++edit' spectregit#core#fnameescape(temp)
  if &foldenable && foldlevel('$') > 0
    set nofoldenable
    silent keepjumps $delete _
    set foldenable
  else
    silent keepjumps $delete _
  endif
  call delete(temp)
  if spectregit#core#cpath(spectregit#core#AbsoluteVimPath(bufnr('$')), temp)
    silent! noautocmd execute bufnr('$') . 'bwipeout'
  endif
endfunction

function! s:TreeChomp(...) abort
  return call('spectregit#core#TreeChomp', a:000)
endfunction

function! spectregit#autocmd#BufReadCmd(...) abort
  let amatch = a:0 ? a:1 : expand('<amatch>')
  let [dir, rev] = s:DirRev(amatch)
  if empty(dir)
    return 'echo "Invalid Fugitive URL"'
  endif
  call s:InitializeBuffer(dir)
  if rev ==# ':'
    return spectregit#status#BufReadStatus(v:cmdbang)
  endif
  try
    if rev =~# '^:\d$'
      let b:fugitive_type = 'stage'
    else
      let r = spectregit#git#Execute([dir, 'cat-file', '-t', rev])
      let b:fugitive_type = get(r.stdout, 0, '')
      if r.exit_status && rev =~# '^:0'
        let r = spectregit#git#Execute([dir, 'write-tree', '--prefix=' . rev[3:-1]])
        let sha = get(r.stdout, 0, '')
        let b:fugitive_type = 'tree'
      endif
      if r.exit_status
        let error = substitute(join(r.stderr, "\n"), "\n*$", '', '')
        unlet b:fugitive_type
        setlocal noswapfile
        if empty(&bufhidden)
          setlocal bufhidden=delete
        endif
        if rev =~# '^:\d:'
          let &l:readonly = !filewritable(spectregit#path#Find('.git/index', dir))
          return 'doautocmd BufNewFile'
        else
          setlocal readonly nomodifiable
          return 'doautocmd BufNewFile|echo ' . string(error)
        endif
      elseif b:fugitive_type !~# '^\%(tag\|commit\|tree\|blob\)$'
        return "echoerr ".string("fugitive: unrecognized git type '".b:fugitive_type."'")
      endif
      if !exists('b:fugitive_display_format') && b:fugitive_type !=# 'blob'
        let b:fugitive_display_format = +getbufvar('#','fugitive_display_format')
      endif
    endif
    if b:fugitive_type !=# 'blob'
      setlocal nomodeline
    endif
    setlocal noreadonly modifiable
    let pos = getpos('.')
    silent keepjumps %delete_
    setlocal endofline
    let events = ['User FugitiveObject', 'User Fugitive' . substitute(b:fugitive_type, '^\l', '\u&', '')]
    try
      if b:fugitive_type !=# 'blob'
        setlocal foldmarker=<<<<<<<<,>>>>>>>>
      endif
      exe s:DoAutocmd('BufReadPre')
      if b:fugitive_type ==# 'tree'
        let b:fugitive_display_format = b:fugitive_display_format % 2
        if b:fugitive_display_format
          call s:ReplaceCmd([dir, 'ls-tree', exists('sha') ? sha : rev])
        else
          if !exists('sha')
            let sha = s:TreeChomp(dir, 'rev-parse', '--verify', rev, '--')
          endif
          call s:ReplaceCmd([dir, 'show', '--no-color', sha])
        endif
      elseif b:fugitive_type ==# 'tag'
        let b:fugitive_display_format = b:fugitive_display_format % 2
        if b:fugitive_display_format
          call s:ReplaceCmd([dir, 'cat-file', b:fugitive_type, rev])
        else
          call s:ReplaceCmd([dir, 'cat-file', '-p', rev])
        endif
      elseif b:fugitive_type ==# 'commit'
        let b:fugitive_display_format = b:fugitive_display_format % 2
        if b:fugitive_display_format
          call s:ReplaceCmd([dir, 'cat-file', b:fugitive_type, rev])
        else
          call s:ReplaceCmd([dir, '-c', 'diff.noprefix=false', '-c', 'log.showRoot=false', 'show', '--no-color', '-m', '--first-parent', '--pretty=format:tree%x20%T%nparent%x20%P%nauthor%x20%an%x20<%ae>%x20%ad%ncommitter%x20%cn%x20<%ce>%x20%cd%nencoding%x20%e%n%n%B', rev])
          keepjumps 1
          keepjumps call search('^parent ')
          if getline('.') ==# 'parent '
            silent lockmarks keepjumps delete_
          else
            silent exe (exists(':keeppatterns') ? 'keeppatterns' : '') 'keepjumps s/\m\C\%(^parent\)\@<! /\rparent /e' . (&gdefault ? '' : 'g')
          endif
          keepjumps let lnum = search('^encoding \%(<unknown>\)\=$','W',line('.')+3)
          if lnum
            silent lockmarks keepjumps delete_
          endif
          silent exe (exists(':keeppatterns') ? 'keeppatterns' : '') 'keepjumps 1,/^diff --git\|\%$/s/\r$//e'
          keepjumps 1
        endif
      elseif b:fugitive_type ==# 'stage'
        call s:ReplaceCmd([dir, 'ls-files', '--stage'])
      elseif b:fugitive_type ==# 'blob'
        let blob_or_filters = rev =~# ':' && spectregit#git#GitVersion(2, 11) ? '--filters' : 'blob'
        call s:ReplaceCmd([dir, 'cat-file', blob_or_filters, rev])
      endif
    finally
      keepjumps call setpos('.',pos)
      setlocal nomodified noswapfile
      let modifiable = rev =~# '^:.:' && b:fugitive_type !=# 'tree'
      if modifiable
        let events = ['User FugitiveStageBlob']
      endif
      let &l:readonly = !modifiable || !filewritable(spectregit#path#Find('.git/index', dir))
      if empty(&bufhidden)
        setlocal bufhidden=delete
      endif
      let &l:modifiable = modifiable
      call spectregit#maps#MapJumps()
      if b:fugitive_type !=# 'blob'
        call s:Map('n', 'a', ":<C-U>let b:fugitive_display_format += v:count1<Bar>exe spectregit#autocmd#BufReadCmd(@%)<CR>", '<silent>')
        call s:Map('n', 'i', ":<C-U>let b:fugitive_display_format -= v:count1<Bar>exe spectregit#autocmd#BufReadCmd(@%)<CR>", '<silent>')
        setlocal filetype=git
      endif
    endtry
    setlocal modifiable
    return s:DoAutocmd('BufReadPost') .
          \ (modifiable ? '' : '|setl nomodifiable') . '|' .
          \ call('s:DoAutocmd', events)
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
endfunction

function! spectregit#autocmd#BufWriteCmd(...) abort
  return ''
endfunction

function! spectregit#autocmd#FileWriteCmd(...) abort
  return ''
endfunction

function! spectregit#autocmd#SourceCmd(...) abort
  return ''
endfunction

function! spectregit#autocmd#TempReadPre(file) abort
  return ''
endfunction

function! spectregit#autocmd#TempReadPost(file) abort
  return ''
endfunction

function! spectregit#autocmd#TempDelete(file) abort
  return spectregit#core#TempDelete(a:file)
endfunction

function! spectregit#autocmd#RunBufDelete(bufnr) abort
  return ''
endfunction

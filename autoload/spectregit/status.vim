if exists('g:autoloaded_spectregit_status') | finish | endif
let g:autoloaded_spectregit_status = 1

function! spectregit#status#StatusCommand(line1, line2, range, count, bang, mods, reg, arg, args, ...) abort
  let dir = a:0 ? spectregit#core#Dir(a:1) : spectregit#core#Dir()
  exe spectregit#core#DirCheck(dir)
  try
    let mods = spectregit#core#Mods(a:mods, 'Edge')
    let file = FugitiveFind(':', dir)
    let arg = ' +setl\ foldmarker=<<<<<<<<,>>>>>>>>\|let\ w:fugitive_status=FugitiveGitDir() ' .
          \ spectregit#core#fnameescape(file)
    for tabnr in [tabpagenr()] + (mods =~# '\<tab\>' ? range(1, tabpagenr('$')) : [])
      let bufs = tabpagebuflist(tabnr)
      for winnr in range(1, tabpagewinnr(tabnr, '$'))
        if spectregit#core#cpath(file, fnamemodify(bufname(bufs[winnr-1]), ':p'))
          if tabnr == tabpagenr() && winnr == winnr()
            call s:ReloadStatus()
          else
            call s:ExpireStatus(dir)
            exe tabnr . 'tabnext'
            exe winnr . 'wincmd w'
          endif
          let w:fugitive_status = dir
          1
          return ''
        endif
      endfor
    endfor
    if a:count ==# 0
      return mods . 'edit' . (a:bang ? '!' : '') . arg
    elseif a:bang
      return mods . 'pedit' . arg . '|wincmd P'
    else
      return mods . 'keepalt split' . arg
    endif
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
  return ''
endfunction

function! s:ReloadStatusBuffer() abort
  if get(b:, 'fugitive_type', '') !=# 'index' || !empty(get(b:, 'fugitive_loading'))
    return ''
  endif
  let original_lnum = line('.')
  let info = spectregit#maps#StageInfo(original_lnum)
  exe fugitive#BufReadStatus(0)
  call setpos('.', [0, s:StageSeek(info, original_lnum), 1, 0])
  return ''
endfunction

function! s:ReloadStatus() abort
  call s:ExpireStatus(-1)
  call s:ReloadStatusBuffer()
  exe spectregit#core#DoAutocmdChanged(-1)
  return ''
endfunction

let s:last_time = reltime()
if !exists('s:last_times')
  let s:last_times = {}
endif

function! s:ExpireStatus(bufnr) abort
  if a:bufnr is# -2 || a:bufnr is# 0
    let s:last_time = reltime()
    return ''
  endif
  let head_file = FugitiveFind('.git/HEAD', a:bufnr)
  if !empty(head_file)
    let s:last_times[spectregit#core#Tree(a:bufnr) . '/'] = reltime()
  endif
  return ''
endfunction

function! s:ReloadWinStatus(...) abort
  if get(b:, 'fugitive_type', '') !=# 'index' || !empty(get(b:, 'fugitive_loading')) || &modified
    return
  endif
  if !exists('b:fugitive_status.reltime')
    exe call('s:ReloadStatusBuffer', a:000)
    return
  endif
  let t = b:fugitive_status.reltime
  if reltimestr(reltime(s:last_time, t)) =~# '-\|\d\{10\}\.' ||
        \ reltimestr(reltime(get(s:last_times, spectregit#core#Tree() . '/', t), t)) =~# '-\|\d\{10\}\.'
    exe call('s:ReloadStatusBuffer', a:000)
  endif
endfunction

function! s:ReloadTabStatus() abort
  if !exists('g:fugitive_did_change_at')
    return
  elseif exists('t:fugitive_reloaded_at')
    let time_ahead = reltime(g:fugitive_did_change_at, t:fugitive_reloaded_at)
    if reltimefloat(time_ahead) >= 0
      return
    endif
  endif
  let t:fugitive_reloaded_at = reltime()
  let winnr = 1
  while winnr <= winnr('$')
    if getbufvar(winbufnr(winnr), 'fugitive_type') ==# 'index'
      if winnr != winnr()
        execute 'noautocmd' winnr.'wincmd w'
        let restorewinnr = 1
      endif
      try
        call s:ReloadWinStatus()
      finally
        if exists('restorewinnr')
          unlet restorewinnr
          noautocmd wincmd p
        endif
      endtry
    endif
    let winnr += 1
  endwhile
endfunction

function! spectregit#status#DidChange(...) abort
  call s:ExpireStatus(a:0 ? a:1 : -1)
  if a:0 > 1 ? a:2 : (!a:0 || a:1 isnot# 0)
    let g:fugitive_did_change_at = reltime()
    call s:ReloadTabStatus()
  else
    call s:ReloadWinStatus()
    return ''
  endif
  exe spectregit#core#DoAutocmdChanged(a:0 ? a:1 : -1)
  return ''
endfunction

function! s:StageSeek(info, fallback) abort
  let info = a:info
  if empty(info.heading)
    return a:fallback
  endif
  let line = search('^' . escape(info.heading, '^$.*[]~\') . ' (\d\++\=)$', 'wn')
  if !line
    for section in get({'Staged': ['Unstaged', 'Untracked'], 'Unstaged': ['Untracked', 'Staged'], 'Untracked': ['Unstaged', 'Staged']}, info.section, [])
      let line = search('^' . section, 'wn')
      if line
        return line + (info.index > 0 ? 1 : 0)
      endif
    endfor
    return 1
  endif
  let i = 0
  while len(getline(line))
    let filename = matchstr(getline(line), '^[A-Z?] \zs.*')
    if len(filename) &&
          \ ((info.filename[-1:-1] ==# '/' && filename[0 : len(info.filename) - 1] ==# info.filename) ||
          \ (filename[-1:-1] ==# '/' && filename ==# info.filename[0 : len(filename) - 1]) ||
          \ filename ==# info.filename)
      if info.offset < 0
        return line
      else
        " Inlined StageInline call (show logic)
        " This needs the full implementation of StageInline if we want the exact behavior
        return line
      endif
    endif
    let commit = matchstr(getline(line), '^\%(\%(\x\x\x\)\@!\l\+\s\+\)\=\zs[0-9a-f]\+')
    if len(commit) && commit ==# info.commit
      return line
    endif
    if i ==# info.index
      let backup = line
    endif
    let i += getline(line) !~# '^[ @\+-]'
    let line += 1
  endwhile
  return exists('backup') ? backup : line - 1
endfunction

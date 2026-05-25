if exists('g:autoloaded_spectregit_quickfix') | finish | endif
let g:autoloaded_spectregit_quickfix = 1

function! s:Get(nr, ...) abort
  if a:nr < 0
    return call('getqflist', a:000)
  else
    return call('getloclist', [a:nr] + a:000)
  endif
endfunction

function! s:Set(nr, ...) abort
  if a:nr < 0
    return call('setqflist', a:000)
  else
    return call('setloclist', [a:nr] + a:000)
  endif
endfunction

function! s:Create(nr, opts) abort
  if has('patch-7.4.2200')
    call s:Set(a:nr, [], ' ', a:opts)
  else
    call s:Set(a:nr, [], ' ')
  endif
endfunction

function! s:Open(nr, mods) abort
  let mods = substitute(spectregit#core#Mods(a:mods), '\<\d*tab\>', '', '')
  return mods . (a:nr < 0 ? 'c' : 'l').'open' . (mods =~# '\<vertical\>' ? ' 20' : '')
endfunction

function! s:BlurStatus() abort
  if (&previewwindow || getwinvar(winnr(), '&winfixbuf') is# 1 || exists('w:fugitive_status')) && get(b:, 'fugitive_type', '') ==# 'index'
    let winnrs = filter([winnr('#')] + range(1, winnr('$')), 'spectregit#core#UsableWin(v:val)')
    if len(winnrs)
      exe winnrs[0].'wincmd w'
    else
      belowright new +setl\ bufhidden=delete
    endif
    if &diff
      call fugitive#DiffClose()
    endif
  endif
endfunction

function! s:SystemList(cmd) abort
  let exit = []
  if exists('*jobstart')
    let lines = ['']
    let jopts = {
          \ 'on_stdout': function('s:NvimCallback', [lines]),
          \ 'on_stderr': function('s:NvimCallback', [lines]),
          \ 'on_exit': { j, code, _ -> add(exit, code) }}
    let job = jobstart(a:cmd, jopts)
    call chanclose(job, 'stdin')
    call jobwait([job])
    if empty(lines[-1])
      call remove(lines, -1)
    endif
    return [lines, exit[0]]
  elseif exists('*ch_close_in')
    let lines = []
    let jopts = {
          \ 'out_cb': { j, str -> add(lines, str) },
          \ 'err_cb': { j, str -> add(lines, str) },
          \ 'exit_cb': { j, code -> add(exit, code) }}
    let job = job_start(a:cmd, jopts)
    call ch_close_in(job)
    while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
      sleep 1m
    endwhile
    return [lines, exit[0]]
  else
    let [output, _] = spectregit#core#LinesError(a:cmd)
    return [output, 0]
  endif
endfunction

function! s:NvimCallback(lines, job, data, type) abort
  let a:lines[-1] .= remove(a:data, 0)
  call extend(a:lines, a:data)
endfunction

function! spectregit#quickfix#Stream(nr, event, title, cmd, first, mods, callback, ...) abort
  call s:BlurStatus()
  let opts = {'title': a:title, 'context': {'items': []}}
  call s:Create(a:nr, opts)
  let event = (a:nr < 0 ? 'c' : 'l') . 'fugitive-' . a:event
  exe spectregit#core#DoAutocmd('QuickFixCmdPre ' . event)
  let winnr = winnr()
  exe s:Open(a:nr, a:mods)
  if winnr != winnr()
    wincmd p
  endif

  let buffer = []
  let lines = s:SystemList(a:cmd)[0]
  for line in lines
    call extend(buffer, call(a:callback, a:000 + [line]))
    if len(buffer) >= 20
      let contexts = map(copy(buffer), 'get(v:val, "context", {})')
      lockvar contexts
      call extend(opts.context.items, contexts)
      unlet contexts
      call s:Set(a:nr, remove(buffer, 0, -1), 'a')
      if a:mods !~# '\<silent\>'
        redraw
      endif
    endif
  endfor
  call extend(buffer, call(a:callback, a:000 + [0]))
  call extend(opts.context.items, map(copy(buffer), 'get(v:val, "context", {})'))
  lockvar opts.context.items
  call s:Set(a:nr, buffer, 'a')

  exe spectregit#core#DoAutocmd('QuickFixCmdPost ' . a:event)
  if a:first
    let list = s:Get(a:nr)
    for index in range(len(list))
      if list[index].valid
        return (index+1) . (a:nr < 0 ? 'cfirst' : 'lfirst')
      endif
    endfor
  endif
  return 'exe'
endfunction

function! spectregit#quickfix#Cwindow() abort
  if &buftype == 'quickfix'
    cwindow
  else
    botright cwindow
    if &buftype == 'quickfix'
      wincmd p
    endif
  endif
endfunction

if exists('g:autoloaded_spectregit_quickfix') | finish | endif
let g:autoloaded_spectregit_quickfix = 1

function! s:QuickfixGet(nr, ...) abort
  if a:nr < 0
    return call('getqflist', a:000)
  else
    return call('getloclist', [a:nr] + a:000)
  endif
endfunction

function! s:QuickfixSet(nr, ...) abort
  if a:nr < 0
    return call('setqflist', a:000)
  else
    return call('setloclist', [a:nr] + a:000)
  endif
endfunction

function! s:QuickfixCreate(nr, opts) abort
  if has('patch-7.4.2200')
    call s:QuickfixSet(a:nr, [], ' ', a:opts)
  else
    call s:QuickfixSet(a:nr, [], ' ')
  endif
endfunction

function! s:QuickfixOpen(nr, mods) abort
  let mods = substitute(spectregit#core#Mods(a:mods), '\<\d*tab\>', '', '')
  return mods . (a:nr < 0 ? 'c' : 'l').'open' . (mods =~# '\<vertical\>' ? ' 20' : '')
endfunction

function! spectregit#quickfix#Stream(nr, event, title, cmd, first, mods, callback, ...) abort
  " BlurStatus is currently internal to fugitive or we need to port it.
  " Assuming we might need it for status buffer interactions.
  " call s:BlurStatus() 

  let opts = {'title': a:title, 'context': {'items': []}}
  call s:QuickfixCreate(a:nr, opts)
  let event = (a:nr < 0 ? 'c' : 'l') . 'fugitive-' . a:event
  exe spectregit#core#DoAutocmd('QuickFixCmdPre ' . event)
  let winnr = winnr()
  exe s:QuickfixOpen(a:nr, a:mods)
  if winnr != winnr()
    wincmd p
  endif

  let buffer = []
  " SystemList needs to be ported or used from fugitive if public.
  " Fugitive's s:SystemList is internal.
  let lines = fugitive#Execute(a:cmd).stdout 
  for line in lines
    call extend(buffer, call(a:callback, a:000 + [line]))
    if len(buffer) >= 20
      let contexts = map(copy(buffer), 'get(v:val, "context", {})')
      lockvar contexts
      call extend(opts.context.items, contexts)
      unlet contexts
      call s:QuickfixSet(a:nr, remove(buffer, 0, -1), 'a')
      if a:mods !~# '\<silent\>'
        redraw
      endif
    endif
  endfor
  call extend(buffer, call(a:callback, a:000 + [0]))
  call extend(opts.context.items, map(copy(buffer), 'get(v:val, "context", {})'))
  lockvar opts.context.items
  call s:QuickfixSet(a:nr, buffer, 'a')

  exe spectregit#core#DoAutocmd('QuickFixCmdPost ' . event)
  if a:first
    let list = s:QuickfixGet(a:nr)
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

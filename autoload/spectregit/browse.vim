if exists('g:autoloaded_spectregit_browse') | finish | endif
let g:autoloaded_spectregit_browse = 1

function! s:UrlEncode(str) abort
  return substitute(a:str, '[%#?&;+=\<> [:cntrl:]]', '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! s:BrowserOpen(url, mods, echo_copy) abort
  let [_, main, query, anchor; __] = matchlist(a:url, '^\([^#?]*\)\(?[^#]*\)\=\(#.*\)\=')
  let url = main . tr(query, ' ', '+') . anchor
  let url = substitute(url, '[ <>\|"]', '\="%".printf("%02X",char2nr(submatch(0)))', 'g')
  let mods = spectregit#core#Mods(a:mods)
  if a:echo_copy
    if has('clipboard')
      let @+ = url
    endif
    return 'echo '.string(url)
  elseif exists(':Browse') == 2
    return 'echo '.string(url).'|' . mods . 'Browse '.url
  elseif exists(':OpenBrowser') == 2
    return 'echo '.string(url).'|' . mods . 'OpenBrowser '.url
  else
    if !exists('g:loaded_netrw')
      runtime! autoload/netrw.vim
      runtime! autoload/netrw/os.vim
    endif
    if exists('*netrw#Open')
      return 'echo '.string(url).'|' . mods . 'call netrw#Open('.string(url).')'
    elseif exists('*netrw#os#Open')
      return 'echo '.string(url).'|' . mods . 'call netrw#os#Open('.string(url).')'
    elseif exists('*netrw#BrowseX')
      return 'echo '.string(url).'|' . mods . 'call netrw#BrowseX('.string(url).', 0)'
    elseif exists('*netrw#NetrwBrowseX')
      return 'echo '.string(url).'|' . mods . 'call netrw#NetrwBrowseX('.string(url).', 0)'
    elseif has('nvim-0.10')
      return mods . 'echo luaeval("({vim.ui.open(_A)})[2] or _A", ' . string(url) . ')'
    else
      return 'echoerr ' . string('Netrw not found. Define your own :Browse to use :GBrowse')
    endif
  endif
endfunction

function! spectregit#browse#BrowseCommand(line1, count, range, bang, mods, arg, ...) abort
  exe spectregit#core#VersionCheck()
  let dir = spectregit#core#Dir()
  try
    let arg = a:arg
    if arg =~# '^++\%([Gg]it\)\=[Rr]emote='
      let remote = matchstr(arg, '^++\%([Gg]it\)\=[Rr]emote=\zs\S\+')
      let arg = matchstr(arg, '\s\zs\S.*')
    endif
    let validremote = '\.\%(git\)\=\|\.\=/.*\|\a[[:alnum:]_-]*\%(://.\{-\}\)\='
    if arg ==# '-'
      let remote = ''
      let rev = ''
      let result = fugitive#Result()
      if filereadable(get(result, 'file', ''))
        let rev = spectregit#core#fnameescape(result.file)
      else
        return 'echoerr ' . string('fugitive: could not find prior :Git invocation')
      endif
    elseif !exists('l:remote')
      let remote = matchstr(arg, '\\\@<!\%(\\\\\)*[!@]\zs\%('.validremote.'\)$')
      let rev = strpart(arg, 0, len(arg) - len(remote) - (empty(remote) ? 0 : 1))
    else
      let rev = arg
    endif
    let expanded = fugitive#Expand(rev)
    if expanded =~? '^\a\a\+:[\/][\/]' && expanded !~? '^fugitive:'
      return s:BrowserOpen(spectregit#core#Slash(expanded), a:mods, a:bang)
    endif
    if !exists('l:result')
      let result = spectregit#core#TempState(empty(expanded) ? bufnr('') : expanded)
    endif
    if !get(result, 'origin_bufnr', 1) && filereadable(get(result, 'file', ''))
      for line in readfile(result.file, '', 4096)
        let rev = spectregit#core#fnameescape(matchstr(line, '\<https\=://[^[:space:]<>]*[^[:space:]<>.,;:"''!?]'))
        if len(rev)
          return s:BrowserOpen(rev, a:mods, a:bang)
        endif
      endfor
      return 'echoerr ' . string('fugitive: no URL found in output of :Git')
    endif
    if empty(remote) && expanded =~# '^[^-./:^~][^:^~]*$' && !empty(dir)
      let config = fugitive#Config(dir)
      if !empty(FugitiveConfigGet('remote.' . expanded . '.url', config))
        let remote = expanded
        let expanded = ''
      endif
    endif
    if empty(expanded)
      let bufname = &buftype =~# '^\%(nofile\|terminal\)$' ? '' : bufname('%')
      let expanded = spectregit#path#Parse(bufname)[0]
    endif
    if empty(remote) && !empty(dir)
      let remote = FugitiveConfigGet('branch.' . spectregit#git#Head(dir) . '.remote', dir)
      if empty(remote)
        let remote = 'origin'
      endif
    endif
    let line1 = a:line1
    let line2 = a:count > 0 ? a:line1 + a:count - 1 : a:line1
    if a:range == 0
      let line1 = 0
      let line2 = 0
    endif
    let opts = {
          \ 'line1': line1,
          \ 'line2': line2,
          \ 'remote': remote}
    return s:BrowserOpen(call('fugitive#BrowseUrl', [expanded, opts] + (empty(dir) ? [] : [dir])), a:mods, a:bang)
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
endfunction

function! spectregit#browse#Open(url, mods, echo_copy) abort
  return s:BrowserOpen(a:url, a:mods, a:echo_copy)
endfunction

function! spectregit#browse#UrlEncode(str) abort
  return s:UrlEncode(a:str)
endfunction

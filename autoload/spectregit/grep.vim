if exists('g:autoloaded_spectregit_grep') | finish | endif
let g:autoloaded_spectregit_grep = 1

let s:grep_combine_flags = '[aiIrhHEGPFnlLzocpWq]\{-\}'

function! s:HasOpt(args, ...) abort
  let args = a:args[0 : index(a:args, '--')]
  let opts = copy(a:000)
  if type(opts[0]) == type([])
    if empty(args) || index(opts[0], args[0]) == -1
      return 0
    endif
    call remove(opts, 0)
  endif
  for opt in opts
    if index(args, opt) != -1
      return 1
    endif
  endfor
endfunction

function! spectregit#grep#ParseLine(options, quiet, dir, line) abort
  if !a:quiet
    echo a:line
  endif
  let entry = {'valid': 1}
  let match = matchlist(a:line, '^\(.\{-\}\):\([1-9]\d*\):\([1-9]\d*:\)\=\(.*\)$')
  if a:line =~# '^git: \|^usage: \|^error: \|^fatal: \|^BUG: '
    return {'text': a:line}
  elseif len(match)
    let entry.module = match[1]
    let entry.lnum = +match[2]
    let entry.col = +match[3]
    let entry.text = match[4]
  else
    let entry.module = matchstr(a:line, '\CBinary file \zs.*\ze matches$')
    if len(entry.module)
      let entry.text = 'Binary file'
      let entry.valid = 0
    endif
  endif
  if empty(entry.module) && !a:options.line_number
    let match = matchlist(a:line, '^\(.\{-\}\):\(.*\)$')
    if len(match)
      let entry.module = match[1]
      let entry.pattern = '\M^' . escape(match[2], '\.^$/') . '$'
    endif
  endif
  if empty(entry.module) && a:options.name_count && a:line =~# ':\d\+$'
    let entry.text = matchstr(a:line, '\d\+$')
    let entry.module = strpart(a:line, 0, len(a:line) - len(entry.text) - 1)
  endif
  if empty(entry.module) && a:options.name_only
    let entry.module = a:line
  endif
  if empty(entry.module)
    return {'text': a:line}
  endif
  if entry.module !~# ':'
    let entry.filename = spectregit#path#Join(a:options.prefix, entry.module)
  else
    let entry.filename = fugitive#Find(matchstr(entry.module, '^[^:]*:') .
          \ substitute(matchstr(entry.module, ':\zs.*'), '/\=:', '/', 'g'), a:dir)
  endif
  return entry
endfunction

function! spectregit#grep#Options(args, dir) abort
  let options = {'name_only': 0, 'name_count': 0, 'line_number': 0}
  let tree = spectregit#core#Tree(a:dir)
  let prefix = empty(tree) ? fugitive#Find(':0:', a:dir) :
        \ spectregit#core#VimSlash(tree . '/')
  let options.prefix = prefix
  for arg in a:args
    if arg ==# '--'
      break
    endif
    if arg =~# '^\%(-' . s:grep_combine_flags . 'c\|--count\)$'
      let options.name_count = 1
    endif
    if arg =~# '^\%(-' . s:grep_combine_flags . 'n\|--line-number\)$'
      let options.line_number = 1
    elseif arg =~# '^\%(--no-line-number\)$'
      let options.line_number = 0
    endif
    if arg =~# '^\%(-' . s:grep_combine_flags . '[lL]\|--files-with-matches\|--name-only\|--files-without-match\)$'
      let options.name_only = 1
    endif
    if arg ==# '--cached'
      let options.prefix = fugitive#Find(':0:', a:dir)
    elseif arg ==# '--no-cached'
      let options.prefix = prefix
    endif
  endfor
  return options
endfunction

function! spectregit#grep#Cfile(result) abort
  let options = spectregit#grep#Options(a:result.args, a:result)
  let entry = spectregit#grep#ParseLine(options, 1, a:result, getline('.'))
  if get(entry, 'col')
    return [entry.filename, entry.lnum, "norm!" . entry.col . "|"]
  elseif has_key(entry, 'lnum')
    return [entry.filename, entry.lnum]
  elseif has_key(entry, 'pattern')
    return [entry.filename, '', 'silent /' . entry.pattern]
  elseif has_key(entry, 'filename')
    return [entry.filename]
  else
    return []
  endif
endfunction

let s:log_diff_context = '{"filename": fugitive#Find(v:val . from, a:dir), "lnum": get(offsets, v:key), "module": strpart(v:val, 0, len(a:state.base_module)) . from}'

function! spectregit#grep#LogFlushQueue(state, dir) abort
  let queue = remove(a:state, 'queue')
  if a:state.child_found && get(a:state, 'ignore_commit')
    call remove(queue, 0)
  elseif len(queue) && len(a:state.target) && len(get(a:state, 'parents', []))
    let from = substitute(a:state.target, '^/', ':', '')
    let offsets = []
    let queue[0].context.diff = map(copy(a:state.parents), s:log_diff_context)
  endif
  if len(queue) && queue[-1] ==# {'text': ''}
    call remove(queue, -1)
  endif
  return queue
endfunction

function! spectregit#grep#LogParse(state, dir, prefix, line) abort
  if a:state.mode ==# 'hunk' && a:line =~# '^[-+ ]'
    return []
  endif
  let list = matchlist(a:line, '^\%(fugitive \(.\{-\}\)\t\|commit \|From \)\=\(\x\{40,\}\)\%( \(.*\)\)\=$')
  if len(list)
    let queue = spectregit#grep#LogFlushQueue(a:state, a:dir)
    let a:state.mode = 'commit'
    let a:state.base = a:prefix . list[2]
    if len(list[1])
      let [a:state.base_module; a:state.parents] = split(list[1], ' ')
    else
      let a:state.base_module = list[2]
      let a:state.parents = []
    endif
    let a:state.message = list[3]
    let a:state.from = ''
    let a:state.to = ''
    let context = {}
    let a:state.queue = [{
          \ 'valid': 1,
          \ 'context': context,
          \ 'filename': spectregit#path#Join(a:state.base, a:state.target),
          \ 'module': a:state.base_module . substitute(a:state.target, '^/', ':', ''),
          \ 'text': a:state.message}]
    let a:state.child_found = 0
    return queue
  elseif type(a:line) == type(0)
    return spectregit#grep#LogFlushQueue(a:state, a:dir)
  elseif a:line =~# '^diff'
    let a:state.mode = 'diffhead'
    let a:state.from = ''
    let a:state.to = ''
  elseif a:state.mode ==# 'diffhead' && a:line =~# '^--- \w/'
    let a:state.from = a:line[6:-1]
    let a:state.to = a:state.from
  elseif a:state.mode ==# 'diffhead' && a:line =~# '^+++ \w/'
    let a:state.to = a:line[6:-1]
    if empty(get(a:state, 'from', ''))
      let a:state.from = a:state.to
    endif
  elseif a:line =~# '^@@[^@]*+\d' && len(get(a:state, 'to', '')) && has_key(a:state, 'base')
    let a:state.mode = 'hunk'
    if empty(a:state.target) || a:state.target ==# '/' . a:state.to
      if !a:state.child_found && len(a:state.queue) && a:state.queue[-1] ==# {'text': ''}
        call remove(a:state.queue, -1)
      endif
      let a:state.child_found = 1
      let offsets = map(split(matchstr(a:line, '^@\+ \zs[-+0-9, ]\+\ze @'), ' '), '+matchstr(v:val, "\\d\\+")')
      let context = {}
      if len(a:state.parents)
        let from = ":" . a:state.from
        let context.diff = map(copy(a:state.parents), s:log_diff_context)
      endif
      call add(a:state.queue, {
            \ 'valid': 1,
            \ 'context': context,
            \ 'filename': spectregit#core#VimSlash(a:state.base . '/' . a:state.to),
            \ 'module': a:state.base_module . ':' . a:state.to,
            \ 'lnum': offsets[-1],
            \ 'text': a:state.message . matchstr(a:line, ' @@\+ .\+')})
    endif
  elseif a:state.follow &&
        \ a:line =~# '^ \%(mode change \d\|\%(create\|delete\) mode \d\|\%(rename\|copy\|rewrite\) .* (\d\+%)$\)'
    let rename = matchstr(a:line, '^ \%(copy\|rename\) \zs.* => .*\ze (\d\+%)$')
    if len(rename)
      let rename = rename =~# '{.* => .*}' ? rename : '{' . rename . '}'
      if a:state.target ==# simplify('/' . substitute(rename, '{.* => \(.*\)}', '\1', ''))
        let a:state.target = simplify('/' . substitute(rename, '{\(.*\) => .*}', '\1', ''))
      endif
    endif
    if !get(a:state, 'ignore_summary')
      call add(a:state.queue, {'text': a:line})
    endif
  elseif a:state.mode ==# 'commit' || a:state.mode ==# 'init'
    call add(a:state.queue, {'text': a:line})
  endif
  return []
endfunction

function! spectregit#grep#GrepComplete(A, L, P) abort
  return spectregit#complete#Sub('grep', a:A, a:L, a:P)
endfunction

function! spectregit#grep#LogComplete(A, L, P) abort
  return spectregit#complete#Sub('log', a:A, a:L, a:P)
endfunction

function! spectregit#grep#GrepCommand(line1, line2, range, bang, mods, arg) abort
  return fugitive#Command(a:line1, a:line2, a:range, a:bang, a:mods,
        \ "grep -O " . a:arg)
endfunction

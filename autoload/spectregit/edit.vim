if exists('g:autoloaded_spectregit_edit') | finish | endif
let g:autoloaded_spectregit_edit = 1

function! s:PlusEscape(string) abort
  return substitute(a:string, '\\*[|" ]', '\=repeat("\\", len(submatch(0))).submatch(0)', 'g')
endfunction

function! s:OpenParse(string, wants_cmd, wants_multiple) abort
  let opts = []
  let cmds = []
  let args = spectregit#core#ArgSplit(a:string)
  while !empty(args)
    if args[0] =~# '^++'
      call add(opts, ' ' . s:PlusEscape(remove(args, 0)))
    elseif a:wants_cmd && args[0] ==# '+'
      call remove(args, 0)
      call add(cmds, '$')
    elseif a:wants_cmd && args[0] =~# '^+'
      call add(cmds, remove(args, 0)[1:-1])
    else
      break
    endif
  endwhile
  if !a:wants_multiple && empty(args)
    let args = ['>:']
  endif
  let dir = spectregit#core#Dir()
  let wants_cmd = a:wants_cmd
  let urls = []
  for arg in args
    let [url, lnum] = s:OpenExpand(dir, arg, wants_cmd)
    if lnum
      call insert(cmds, lnum)
    endif
    call add(urls, url)
    let wants_cmd = 0
  endfor

  let pre = join(opts, '')
  if len(cmds) > 1
    let pre .= ' +' . s:PlusEscape(join(map(cmds, '"exe ".string(v:val)'), '|'))
  elseif len(cmds)
    let pre .= ' +' . s:PlusEscape(cmds[0])
  endif
  return [a:wants_multiple ? urls : urls[0], pre]
endfunction

function! s:OpenExpand(dir, file, wants_cmd) abort
  if a:file ==# '-'
    let result = fugitive#Result()
    if has_key(result, 'file')
      let efile = result.file
    else
      throw 'fugitive: no previous command output'
    endif
  else
    let efile = s:Expand(a:file)
  endif
  if efile =~# '^https\=://'
    let [url, lnum] = s:ResolveUrl(efile, a:dir)
    return [url, a:wants_cmd ? lnum : 0]
  endif
  let url = spectregit#path#Generate(efile, a:dir)
  if a:wants_cmd && a:file[0] ==# '>' && efile[0] !=# '>' && get(b:, 'fugitive_type', '') isnot# 'tree' && &filetype !=# 'netrw'
    let line = line('.')
    if spectregit#core#Slash(expand('%:p')) !=# spectregit#core#Slash(url)
      let diffcmd = 'diff'
      let from = reverse(spectregit#path#Parse(@%))[1]
      let to = reverse(spectregit#path#Parse(url))[1]
      if empty(from) && empty(to)
        let diffcmd = 'diff-files'
        let args = ['--', expand('%:p'), url]
      elseif empty(to)
        let args = [from, '--', url]
      elseif empty(from)
        let args = [to, '--', expand('%:p')]
        let reverse = 1
      else
        let args = [from, to]
      endif
      let [res, exec_error] = spectregit#core#LinesError([a:dir, diffcmd, '-U0'] + args)
      if !exec_error
        call filter(res, 'v:val =~# "^@@ "')
        call map(res, 'substitute(v:val, ''[-+]\d\+\zs '', ",1 ", "g")')
        call map(res, 'matchlist(v:val, ''^@@ -\(\d\+\),\(\d\+\) +\(\d\+\),\(\d\+\) @@'')[1:4]')
        if exists('reverse')
          call map(res, 'v:val[2:3] + v:val[0:1]')
        endif
        call filter(res, 'v:val[0] < '.line('.'))
        let hunk = get(res, -1, [0,0,0,0])
        if hunk[0] + hunk[1] > line('.')
          let line = hunk[2] + max([1 - hunk[3], 0])
        else
          let line = hunk[2] + max([hunk[3], 1]) + line('.') - hunk[0] - max([hunk[1], 1])
        endif
      endif
    endif
    return [url, line]
  endif
  return [url, 0]
endfunction

function! spectregit#edit#DiffClose() abort
  let mywinnr = winnr()
  for winnr in [winnr('#')] + range(winnr('$'),1,-1)
    if winnr != mywinnr && getwinvar(winnr,'&diff')
      execute winnr.'wincmd w'
      close
      if winnr('$') > 1
        wincmd p
      endif
    endif
  endfor
  diffoff!
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
      call spectregit#edit#DiffClose()
    endif
  endif
endfunction

let s:bang_edits = {'split': 'Git', 'vsplit': 'vertical Git', 'tabedit': 'tab Git', 'pedit': 'Git!'}
function! spectregit#edit#Open(cmd, bang, mods, arg, ...) abort
  exe spectregit#core#VersionCheck()
  if a:bang
    return 'echoerr ' . string(':G' . a:cmd . '! for temp buffer output has been replaced by :Git --paginate')
  endif

  try
    let [file, pre] = s:OpenParse(a:arg, 1, 0)
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
  let mods = spectregit#core#Mods(a:mods)
  if a:cmd ==# 'edit'
    call s:BlurStatus()
  endif
  return mods . a:cmd . pre . ' ' . spectregit#core#fnameescape(file)
endfunction

function! spectregit#edit#DropCommand(line1, count, range, bang, mods, arg, ...) abort
  exe spectregit#core#VersionCheck()

  let mods = spectregit#core#Mods(a:mods)
  try
    let [files, pre] = s:OpenParse(a:arg, 1, 1)
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
  if empty(files)
    return 'drop'
  endif
  call s:BlurStatus()
  return mods . 'drop' . ' ' . spectregit#core#fnameescape(files) . substitute(pre, '^ *+', '|', '')
endfunction

function! s:ReadPrepare(line1, count, range, mods) abort
  let mods = spectregit#core#Mods(a:mods)
  let after = a:count
  if a:count < 0
    let delete = 'silent 1,' . line('$') . 'delete_|'
    let after = line('$')
  elseif a:range == 2
    let delete = 'silent ' . a:line1 . ',' . a:count . 'delete_|'
  else
    let delete = ''
  endif
  if foldlevel(after)
    let pre = after . 'foldopen!|'
  else
    let pre = ''
  endif
  return [pre . 'keepalt ' . mods . after . 'read', '|' . delete . 'diffupdate' . (a:count < 0 ? '|' . line('.') : '')]
endfunction

function! spectregit#edit#ReadCommand(line1, count, range, bang, mods, arg, ...) abort
  exe spectregit#core#VersionCheck()
  let [read, post] = s:ReadPrepare(a:line1, a:count, a:range, a:mods)
  try
    let [file, pre] = s:OpenParse(a:arg, 0, 0)
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
  if file =~# '^fugitive:' && a:count is# 0
    return 'exe ' .string('keepalt ' . spectregit#core#Mods(a:mods) . fugitive#FileReadCmd(file, 0, pre)) . '|diffupdate'
  endif
  return read . ' ' . pre . ' ' . spectregit#core#fnameescape(file) . post
endfunction

function! spectregit#edit#Complete(A, L, P) abort
  if a:A =~# '^>'
    return map(s:FilterEscape(spectregit#git#CompleteHeads(spectregit#core#Dir()), a:A[1:-1]), "'>' . v:val")
  else
    return spectregit#complete#Object(a:A, a:L, a:P)
  endif
endfunction

function! spectregit#edit#ReadComplete(A, L, P) abort
  return spectregit#edit#Complete(a:A, a:L, a:P)
endfunction

" Helper functions ported from fugitive.vim

function! s:Expand(rev, ...) abort
  let rev = a:rev
  if rev =~# '^>' && spectregit#core#Slash(@%) =~# '^fugitive://' && empty(spectregit#core#DirCommitFile(@%)[1])
    return spectregit#core#Slash(@%)
  elseif rev =~# '^>\=:[0-3]$'
    let file = len(expand('%')) ? rev[-2:-1] . ':%' : '%'
  elseif rev =~# '^>\%(:\=/\)\=$'
    let file = '%'
  elseif rev =~# '^>[> ]\@!' && @% !~# '^fugitive:' && spectregit#core#Slash(@%) =~# '://\|^$'
    let file = '%'
  elseif rev ==# '>:'
    let file = empty(spectregit#core#DirCommitFile(@%)[0]) ? ':0:%' : '%'
  elseif rev =~# '^>[> ]\@!'
    let r = (rev =~# '^>[~^]' ? '!' : '') . rev[1:-1]
    let prefix = matchstr(r, '^\%(\\.\|{[^{}]*}\|[^:]\)*')
    if prefix !=# r
      let file = r
    else
      let file = len(expand('%')) ? r . ':%' : '%'
    endif
  elseif spectregit#core#Slash(rev) =~# '^\a\a\+://'
    let file = substitute(rev, '\\\@<!\%(#\a\|%\x\x\)', '\\&', 'g')
  elseif rev =~# '^:[!#%$]'
    let file = ':0' . rev
  else
    let file = rev
  endif
  return fugitive#Expand(file)
endfunction

function! s:ResolveUrl(target, ...) abort
  return call('fugitive#ResolveUrl', [a:target] + a:000)
endfunction

function! s:FilterEscape(items, ...) abort
  let items = copy(a:items)
  call map(items, 'fnameescape(v:val)')
  if !a:0 || type(a:1) != type('')
    let match = ''
  else
    let match = substitute(a:1, '^[+>]\|\\\@<![ \t\n*?[{`$\%#''"|!<]', '\\&', 'g')
  endif
  let cmp = spectregit#core#FileIgnoreCase(1) ? '==?' : '==#'
  return filter(items, 'strpart(v:val, 0, strlen(match)) ' . cmp . ' match')
endfunction

if exists('g:autoloaded_spectregit_diff') | finish | endif
let g:autoloaded_spectregit_diff = 1

function! s:Relative(...) abort
  return spectregit#path#Path(@%, a:0 ? a:1 : ':(top)', a:0 > 1 ? a:2 : spectregit#core#Dir())
endfunction

function! s:DiffModifier(count, default) abort
  let fdc = matchstr(&diffopt, 'foldcolumn:\zs\d\+')
  if &diffopt =~# 'horizontal' && &diffopt !~# 'vertical'
    return ''
  elseif &diffopt =~# 'vertical'
    return 'vertical '
  elseif !get(g:, 'fugitive_diffsplit_directional_fit', a:default)
    return ''
  elseif winwidth(0) <= a:count * ((&tw ? &tw : 80) + (empty(fdc) ? 2 : fdc))
    return ''
  else
    return 'vertical '
  endif
endfunction

function! s:diff_window_count() abort
  let c = 0
  for nr in range(1,winnr('$'))
    let c += getwinvar(nr,'&diff')
  endfor
  return c
endfunction

function! s:diffthis() abort
  if !&diff
    let w:fugitive_diff_restore = 1
    diffthis
  endif
endfunction

function! s:diffoff() abort
  unlet! w:fugitive_diff_restore
  diffoff
endfunction

function! s:diffoff_all(dir) abort
  let curwin = winnr()
  for nr in range(1,winnr('$'))
    if getwinvar(nr, '&diff') && !empty(getwinvar(nr, 'fugitive_diff_restore'))
      call setwinvar(nr, 'fugitive_diff_restore', '')
    endif
  endfor
  if curwin != winnr()
    execute curwin.'wincmd w'
  endif
  diffoff!
endfunction

function! s:IsConflicted() abort
  return len(@%) && !empty(spectregit#core#ChompDefault('', ['ls-files', '--unmerged', '--', expand('%:p')]))
endfunction

function! spectregit#diff#CanDiffoff(buf) abort
  return getwinvar(bufwinnr(bufnr(a:buf)), '&diff') &&
        \ !empty(getwinvar(bufwinnr(bufnr(a:buf)), 'fugitive_diff_restore'))
endfunction

function! spectregit#diff#DiffClose() abort
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

function! spectregit#diff#Diffsplit(autodir, keepfocus, mods, arg, ...) abort
  exe spectregit#core#VersionCheck()
  let args = spectregit#core#ArgSplit(a:arg)
  let post = ''
  let autodir = a:autodir
  while get(args, 0, '') =~# '^++'
    if args[0] =~? '^++novertical$'
      let autodir = 0
    else
      return 'echoerr ' . string('fugitive: unknown option ' . args[0])
    endif
    call remove(args, 0)
  endwhile
  if get(args, 0) =~# '^+'
    let post = remove(args, 0)[1:-1]
  endif
  if exists(':DiffGitCached') && empty(args)
    return spectregit#core#Mods(a:mods) . 'DiffGitCached' . (len(post) ? '|' . post : '')
  endif
  let commit = spectregit#core#DirCommitFile(@%)[1]
  if a:mods =~# '\<\d*tab\>'
    let mods = substitute(a:mods, '\<\d*tab\>', '', 'g')
    let pre = matchstr(a:mods, '\<\d*tab\>') . ' split'
  else
    let mods = 'keepalt ' . a:mods
    let pre = ''
  endif
  let back = exists('*win_getid') ? 'call win_gotoid(' . win_getid() . ')' : 'wincmd p'
  if (empty(args) || args[0] =~# '^>\=:$') && a:keepfocus
    exe spectregit#core#DirCheck()
    if commit =~# '^1\=$' && s:IsConflicted()
      let parents = [s:Relative(':2:'), s:Relative(':3:')]
    elseif empty(commit)
      let parents = [s:Relative(':0:')]
    elseif commit =~# '^\d\=$'
      let parents = [s:Relative('@:')]
    elseif commit =~# '^\x\x\+$'
      let parents = spectregit#core#LinesError(['rev-parse', commit . '^@'])[0]
      call map(parents, 's:Relative(v:val . ":")')
    endif
  endif
  try
    if exists('parents') && len(parents) > 1
      exe pre
      let mods = (autodir ? s:DiffModifier(len(parents) + 1, empty(args) || args[0] =~# '^>') : '') . spectregit#core#Mods(mods, 'leftabove')
      let nr = bufnr('')
      if len(parents) > 1 && !&equalalways
        let equalalways = 0
        set equalalways
      endif
      execute mods 'split' spectregit#core#fnameescape(fugitive#Find(parents[0]))
      execute 'nnoremap <buffer> <silent> dp :diffput '.nr.'<Bar>diffupdate<CR>'
      let nr2 = bufnr('')
      call s:diffthis()
      exe back
      execute 'nnoremap <buffer> <silent> d2o :diffget '.nr2.'<Bar>diffupdate<CR>'
      let mods = substitute(mods, '\Cleftabove\|rightbelow\|aboveleft\|belowright', '\=submatch(0) =~# "f" ? "rightbelow" : "leftabove"', '')
      for i in range(len(parents)-1, 1, -1)
        execute mods 'split' spectregit#core#fnameescape(fugitive#Find(parents[i]))
        execute 'nnoremap <buffer> <silent> dp :diffput '.nr.'<Bar>diffupdate<CR>'
        let nrx = bufnr('')
        call s:diffthis()
        exe back
        execute 'nnoremap <buffer> <silent> d' . (i + 2) . 'o :diffget '.nrx.'<Bar>diffupdate<CR>'
      endfor
      call s:diffthis()
      return post
    elseif len(args)
      let arg = join(args, ' ')
      if arg ==# ''
        return post
      elseif arg ==# ':/'
        exe spectregit#core#DirCheck()
        let file = s:Relative()
      elseif arg ==# ':'
        exe spectregit#core#DirCheck()
        let file = len(commit) ? s:Relative() : s:Relative(s:IsConflicted() ? ':1:' : ':0:')
      elseif arg =~# '^:\d$'
        exe spectregit#core#DirCheck()
        let file = s:Relative(arg . ':')
      elseif arg =~# '^[~^]\d*$'
        return 'echoerr ' . string('fugitive: change ' . arg . ' to !' . arg . ' to diff against ancestor')
      else
        try
          let file = arg =~# '^:/.' ? fugitive#RevParse(arg) . s:Relative(':') : fugitive#Expand(arg)
        catch /^fugitive:/
          return 'echoerr ' . string(v:exception)
        endtry
      endif
      if a:keepfocus || arg =~# '^>'
        let mods = spectregit#core#Mods(a:mods, 'leftabove')
      else
        let mods = spectregit#core#Mods(a:mods)
      endif
    elseif exists('parents')
      let file = get(parents, -1, s:Relative(repeat('0', 40). ':'))
      let mods = spectregit#core#Mods(a:mods, 'leftabove')
    elseif len(commit)
      let file = s:Relative()
      let mods = spectregit#core#Mods(a:mods, 'rightbelow')
    elseif s:IsConflicted()
      let file = s:Relative(':1:')
      let mods = spectregit#core#Mods(a:mods, 'leftabove')
      if get(g:, 'fugitive_legacy_commands', 1)
        let post = 'echohl WarningMsg|echo "Use :Gdiffsplit! for 3 way diff"|echohl NONE|' . post
      endif
    else
      exe spectregit#core#DirCheck()
      let file = s:Relative(':0:')
      let mods = spectregit#core#Mods(a:mods, 'leftabove')
    endif
    let spec = spectregit#path#Generate(file)
    if spec =~# '^fugitive:' && empty(spectregit#core#DirCommitFile(spec)[2])
      let spec = spectregit#core#VimSlash(spec . s:Relative('/'))
    endif
    exe pre
    let w:fugitive_diff_restore = 1
    let mods = (autodir ? s:DiffModifier(2, empty(args) || args[0] =~# '^>') : '') . mods
    if &diffopt =~# 'vertical'
      let diffopt = &diffopt
      set diffopt-=vertical
    endif
    execute mods 'diffsplit' spectregit#core#fnameescape(spec)
    let w:fugitive_diff_restore = 1
    let winnr = winnr()
    if getwinvar('#', '&diff')
      if a:keepfocus
        exe back
      endif
    endif
    return post
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  finally
    if exists('l:equalalways')
      let &g:equalalways = equalalways
    endif
    if exists('diffopt')
      let &diffopt = diffopt
    endif
  endtry
endfunction

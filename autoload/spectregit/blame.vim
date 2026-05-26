if exists('g:autoloaded_spectregit_blame') | finish | endif
let g:autoloaded_spectregit_blame = 1

let s:hash_colors = {}

function! s:BlameBufnr(...) abort
  let state = spectregit#core#TempState(a:0 ? a:1 : bufnr(''))
  if get(state, 'filetype', '') ==# 'fugitiveblame'
    return get(state, 'origin_bufnr', -1)
  else
    return -1
  endif
endfunction

function! s:BlameCommitFileLnum(...) abort
  let line = a:0 ? a:1 : getline('.')
  let state = a:0 > 1 ? a:2 : spectregit#core#TempState()
  if get(state, 'filetype', '') !=# 'fugitiveblame'
    return ['', '', 0]
  endif
  let commit = matchstr(line, '^\^\=[?*]*\zs\x\+')
  if commit =~# '^0\+$'
    let commit = ''
  elseif has_key(state, 'blame_reverse_end')
    let commit = get(spectregit#core#LinesError([state.git_dir, 'rev-list', '--ancestry-path', '--reverse', commit . '..' . state.blame_reverse_end])[0], 0, '')
  endif
  let lnum = +matchstr(line, ' \zs\d\+\ze \%((\| *\d\+)\)')
  let path = matchstr(line, '^\^\=[?*]*\x* \+\%(\d\+ \+\d\+ \+\)\=\zs.\{-\}\ze\s*\d\+ \%((\| *\d\+)\)')
  if empty(path) && lnum
    let path = get(state, 'blame_file', '')
  endif
  return [commit, path, lnum]
endfunction

function! s:BlameLeave() abort
  let state = spectregit#core#TempState()
  let bufwinnr = exists('*win_id2win') ? win_id2win(get(state, 'origin_winid')) : 0
  if bufwinnr == 0
    let bufwinnr = bufwinnr(get(state, 'origin_bufnr', -1))
  endif
  if get(state, 'filetype', '') ==# 'fugitiveblame' && bufwinnr > 0
    let bufnr = bufnr('')
    exe bufwinnr . 'wincmd w'
    return bufnr . 'bdelete'
  endif
  return ''
endfunction

function! s:BlameQuit() abort
  let cmd = s:BlameLeave()
  if empty(cmd)
    return 'bdelete'
  elseif len(spectregit#core#DirCommitFile(@%)[1])
    return cmd . '|Gedit'
  else
    return cmd
  endif
endfunction

function! spectregit#blame#Complete(A, L, P) abort
  return spectregit#complete#Sub('blame', a:A, a:L, a:P)
endfunction

function! s:BlameCommit(cmd, ...) abort
  let line = a:0 ? a:1 : getline('.')
  let state = a:0 > 1 ? a:2 : spectregit#core#TempState()
  let sigil = has_key(state, 'blame_reverse_end') ? '-' : '+'
  let mods = (s:BlameBufnr() < 0 ? '' : &splitbelow ? "botright " : "topleft ")
  let [commit, path, lnum] = s:BlameCommitFileLnum(line, state)
  if empty(commit) && len(path) && has_key(state, 'blame_reverse_end')
    let path = (len(state.blame_reverse_end) ? state.blame_reverse_end . ':' : ':(top)') . path
    return fugitive#Open(mods . a:cmd, 0, '', '+' . lnum . ' ' . spectregit#core#fnameescape(path), ['+' . lnum, path])
  endif
  if commit =~# '^0*$'
    return 'echoerr ' . string('fugitive: no commit')
  endif
  if line =~# '^\^' && !has_key(state, 'blame_reverse_end')
    let path = commit . ':' . path
    return fugitive#Open(mods . a:cmd, 0, '', '+' . lnum . ' ' . spectregit#core#fnameescape(path), ['+' . lnum, path])
  endif
  let cmd = fugitive#Open(mods . a:cmd, 0, '', commit, [commit])
  if cmd =~# '^echoerr'
    return cmd
  endif
  execute cmd
  if a:cmd ==# 'pedit' || empty(path)
    return ''
  endif
  if search('^diff .* b/\M'.escape(path,'\').'$','W')
    call search('^+++')
    let head = line('.')
    while search('^@@ \|^diff ') && getline('.') =~# '^@@ '
      let top = +matchstr(getline('.'),' ' . sigil .'\zs\d\+')
      let len = +matchstr(getline('.'),' ' . sigil . '\d\+,\zs\d\+')
      if lnum >= top && lnum <= top + len
        let offset = lnum - top
        if &scrolloff
          +
          normal! zt
        else
          normal! zt
          +
        endif
        while offset > 0 && line('.') < line('$')
          +
          if getline('.') =~# '^[ ' . sigil . ']'
            let offset -= 1
          endif
        endwhile
        return 'normal! zv'
      endif
    endwhile
    execute head
    normal! zt
  endif
  return ''
endfunction

function! s:BlameJump(suffix, ...) abort
  let suffix = a:suffix
  let [commit, path, lnum] = s:BlameCommitFileLnum()
  if empty(path)
    return 'echoerr ' . string('fugitive: could not determine filename for blame')
  endif
  if commit =~# '^0*$'
    let commit = '@'
    let suffix = ''
  endif
  let offset = line('.') - line('w0')
  let state = spectregit#core#TempState()
  let flags = get(state, 'blame_flags', [])
  let blame_bufnr = s:BlameBufnr()
  if blame_bufnr > 0
    let bufnr = bufnr('')
    let winnr = bufwinnr(blame_bufnr)
    if winnr > 0
      exe winnr.'wincmd w'
      exe bufnr.'bdelete'
    endif
    execute 'Gedit' spectregit#core#fnameescape(commit . suffix . ':' . path)
    execute lnum
  endif
  let my_bufnr = bufnr('')
  if blame_bufnr < 0
    let blame_args = flags + [commit . suffix, '--', path]
    let result = spectregit#blame#Subcommand(0, 0, 0, 0, '', extend({'subcommand_args': blame_args}, state.blame_options, 'keep'))
  else
    let blame_args = flags
    let result = spectregit#blame#Subcommand(-1, -1, 0, 0, '', extend({'subcommand_args': blame_args}, state.blame_options, 'keep'))
  endif
  if bufnr('') == my_bufnr
    return result
  endif
  execute result
  execute lnum
  let delta = line('.') - line('w0') - offset
  if delta > 0
    execute 'normal! '.delta."\<C-E>"
  elseif delta < 0
    execute 'normal! '.(-delta)."\<C-Y>"
  endif
  keepjumps syncbind
  redraw
  echo ':Git blame' spectregit#core#fnameescape(blame_args)
  return ''
endfunction

function! spectregit#blame#Syntax() abort
  let conceal = has('conceal') ? ' conceal' : ''
  let flags = get(spectregit#core#TempState(), 'blame_flags', [])
  syn spell notoplevel
  syn match FugitiveblameBlank                      "^\s\+\s\@=" nextgroup=FugitiveblameAnnotation,FugitiveblameScoreDebug,FugitiveblameOriginalFile,FugitiveblameOriginalLineNumber skipwhite
  syn match FugitiveblameHash       "\%(^\^\=[?*]*\)\@<=\<\x\{7,\}\>" nextgroup=FugitiveblameAnnotation,FugitiveblameScoreDebug,FugitiveblameOriginalLineNumber,FugitiveblameOriginalFile skipwhite
  if spectregit#core#HasOpt(flags, '-b') || FugitiveConfigGet('blame.blankBoundary') =~# '^1$\|^true$'
    syn match FugitiveblameBoundaryIgnore "^\^[*?]*\x\{7,\}\>" nextgroup=FugitiveblameAnnotation,FugitiveblameScoreDebug,FugitiveblameOriginalLineNumber,FugitiveblameOriginalFile skipwhite
  else
    syn match FugitiveblameBoundary "^\^"
  endif
  syn match FugitiveblameScoreDebug        " *\d\+\s\+\d\+\s\@=" nextgroup=FugitiveblameAnnotation,FugitiveblameOriginalLineNumber,fugitiveblameOriginalFile contained skipwhite
  syn region FugitiveblameAnnotation matchgroup=FugitiveblameDelimiter start="(" end="\%(\s\d\+\)\@<=)" contained keepend oneline
  syn match FugitiveblameTime "\<[0-9:/+-][0-9:/+ -]*[0-9:/+-]\%(\s\+\d\+)\)\@=" contained containedin=FugitiveblameAnnotation
  exec 'syn match FugitiveblameLineNumber         "\s[[:digit:][:space:]]\{0,' . (len(line('$'))-1). '\}\d)\@=" contained containedin=FugitiveblameAnnotation' conceal
  exec 'syn match FugitiveblameOriginalFile       "\s\%(\f\+\D\@<=\|\D\@=\f\+\)\%(\%(\s\+\d\+\)\=\s\%((\|\s*\d\+)\)\)\@=" contained nextgroup=FugitiveblameOriginalLineNumber,FugitiveblameAnnotation skipwhite' (spectregit#core#HasOpt(flags, '--show-name', '-f') ? '' : conceal)
  exec 'syn match FugitiveblameOriginalLineNumber "\s*\d\+\%(\s(\)\@=" contained nextgroup=FugitiveblameAnnotation skipwhite' (spectregit#core#HasOpt(flags, '--show-number', '-n') ? '' : conceal)
  exec 'syn match FugitiveblameOriginalLineNumber "\s*\d\+\%(\s\+\d\+)\)\@=" contained nextgroup=FugitiveblameShort skipwhite' (spectregit#core#HasOpt(flags, '--show-number', '-n') ? '' : conceal)
  syn match FugitiveblameShort              " \+\d\+)" contained contains=FugitiveblameLineNumber
  syn match FugitiveblameNotCommittedYet "(\@<=Not Committed Yet\>" contained containedin=FugitiveblameAnnotation
  hi def link FugitiveblameBoundary           Keyword
  hi def link FugitiveblameHash               Identifier
  hi def link FugitiveblameBoundaryIgnore     Ignore
  hi def link FugitiveblameUncommitted        Ignore
  hi def link FugitiveblameScoreDebug         Debug
  hi def link FugitiveblameTime               PreProc
  hi def link FugitiveblameLineNumber         Number
  hi def link FugitiveblameOriginalFile       String
  hi def link FugitiveblameOriginalLineNumber Float
  hi def link FugitiveblameShort              FugitiveblameDelimiter
  hi def link FugitiveblameDelimiter          Delimiter
  hi def link FugitiveblameNotCommittedYet    Comment
  if !get(g:, 'fugitive_dynamic_colors', 1) && !spectregit#core#HasOpt(flags, '--color-lines') || spectregit#core#HasOpt(flags, '--no-color-lines')
    return
  endif
  let seen = {}
  for x in split('01234567890abcdef', '\zs')
    exe 'syn match FugitiveblameHashGroup'.x '"\%(^\^\=[*?]*\)\@<='.x.'\x\{5,\}\>" nextgroup=FugitiveblameAnnotation,FugitiveblameOriginalLineNumber,fugitiveblameOriginalFile skipwhite'
  endfor
  for lnum in range(1, line('$'))
    let orig_hash = matchstr(getline(lnum), '^\^\=[*?]*\zs\x\{6\}')
    let hash = orig_hash
    let hash = substitute(hash, '\(\x\)\x', '\=submatch(1).printf("%x", 15-str2nr(submatch(1),16))', 'g')
    let hash = substitute(hash, '\(\x\x\)', '\=printf("%02x", str2nr(submatch(1),16)*3/4+32)', 'g')
    if hash ==# '' || orig_hash ==# '000000' || has_key(seen, hash)
      continue
    endif
    let seen[hash] = 1
    if &t_Co == 256
      let [s, r, g, b; __] = map(matchlist(orig_hash, '\(\x\)\x\(\x\)\x\(\x\)\x'), 'str2nr(v:val,16)')
      let color = 16 + (r + 1) / 3 * 36 + (g + 1) / 3 * 6 + (b + 1) / 3
      if color == 16
        let color = 235
      elseif color == 231
        let color = 255
      endif
      let s:hash_colors[hash] = ' ctermfg='.color
    else
      let s:hash_colors[hash] = ''
    endif
    let pattern = substitute(orig_hash, '^\(\x\)\x\(\x\)\x\(\x\)\x$', '\1\\x\2\\x\3\\x', '') . '*'
    exe 'syn match FugitiveblameHash'.hash.'       "\%(^\^\=[*?]*\)\@<='.pattern.'" contained containedin=FugitiveblameHashGroup' . orig_hash[0]
  endfor
  syn match FugitiveblameUncommitted "\%(^\^\=[?*]*\)\@<=\<0\{7,\}\>" nextgroup=FugitiveblameAnnotation,FugitiveblameScoreDebug,FugitiveblameOriginalLineNumber,FugitiveblameOriginalFile skipwhite
  call s:BlameRehighlight()
endfunction

function! s:BlameRehighlight() abort
  for [hash, cterm] in items(s:hash_colors)
    if !empty(cterm) || has('gui_running') || has('termguicolors') && &termguicolors
      exe 'hi FugitiveblameHash'.hash.' guifg=#' . hash . cterm
    else
      exe 'hi link FugitiveblameHash'.hash.' Identifier'
    endif
  endfor
endfunction

function! s:BlameMaps(is_ftplugin) abort
  let ft = a:is_ftplugin
  call spectregit#maps#MapGitOps(ft)
  call spectregit#maps#Map('n', '<F1>', ':help :Git_blame<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'g?',   ':help :Git_blame<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'gq',   ':exe <SID>BlameQuit()<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', '<2-LeftMouse>', ':<C-U>exe <SID>BlameCommit("exe <SID>BlameLeave()<Bar>edit")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', '<CR>', ':<C-U>exe <SID>BlameCommit("exe <SID>BlameLeave()<Bar>edit")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', '-',    ':<C-U>exe <SID>BlameJump("")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 's',    ':<C-U>exe <SID>BlameJump("")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'u',    ':<C-U>exe <SID>BlameJump("")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'P',    ':<C-U>if !v:count<Bar>echoerr "Use ~ (or provide a count)"<Bar>else<Bar>exe <SID>BlameJump("^".v:count1)<Bar>endif<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', '~',    ':<C-U>exe <SID>BlameJump("~".v:count1)<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'i',    ':<C-U>exe <SID>BlameCommit("exe <SID>BlameLeave()<Bar>edit")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'o',    ':<C-U>exe <SID>BlameCommit("split")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'O',    ':<C-U>exe <SID>BlameCommit("tabedit")<CR>', '<silent>', ft)
  call spectregit#maps#Map('n', 'p',    ':<C-U>exe <SID>BlameCommit("pedit")<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', '.',    ":<C-U> <C-R>=substitute(<SID>BlameCommitFileLnum()[0],'^$','@','')<CR><Home>", '', ft)
  exe spectregit#maps#Map('n', '(',    "-", '', ft)
  exe spectregit#maps#Map('n', ')',    "+", '', ft)
  call spectregit#maps#Map('n', 'A',    ":<C-u>exe 'vertical resize '.(spectregit#core#LineChars('.\\{-\\}\\ze [0-9:/+-][0-9:/+ -]* \\d\\+)')+1+v:count)<CR>", '<silent>', ft)
  call spectregit#maps#Map('n', 'C',    ":<C-u>exe 'vertical resize '.(spectregit#core#LineChars('^\\S\\+')+1+v:count)<CR>", '<silent>', ft)
  call spectregit#maps#Map('n', 'D',    ":<C-u>exe 'vertical resize '.(spectregit#core#LineChars('.\\{-\\}\\ze\\d\\ze\\s\\+\\d\\+)')+1-v:count)<CR>", '<silent>', ft)
endfunction

function! spectregit#blame#FileType() abort
  setlocal nomodeline
  setlocal foldmethod=manual
  if len(spectregit#core#Dir())
    let &l:keywordprg = FugitiveGitPath(spectregit#core#Dir()) . ' show'
  endif
  let b:undo_ftplugin = 'setl keywordprg= foldmethod<'
  if exists('+concealcursor')
    setlocal concealcursor=nc conceallevel=2
    let b:undo_ftplugin .= ' concealcursor< conceallevel<'
  endif
  if &modifiable
    return ''
  endif
  call s:BlameMaps(1)
endfunction

function! spectregit#blame#Subcommand(line1, count, range, bang, mods, options) abort
  " To be implemented, but needs more research into fugitive#Subcommand logic
  return 'echoerr "spectregit#blame#Subcommand not yet implemented"'
endfunction

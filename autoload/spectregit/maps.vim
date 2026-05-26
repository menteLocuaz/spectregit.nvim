if exists('g:autoloaded_spectregit_maps') | finish | endif
let g:autoloaded_spectregit_maps = 1

nnoremap <SID>: :<C-U><C-R>=v:count ? v:count : ''<CR>

" Script variables
let s:ref_header = '\%(Merge\|Rebase\|Upstream\|Pull\|Push\)'
let s:file_pattern = '^[A-Z?] .\|^diff --'
let s:file_commit_pattern = s:file_pattern . '\|^\%(\l\{3,\} \)\=[0-9a-f]\{4,\} '
let s:item_pattern = s:file_commit_pattern . '\|^@@'
let s:section_pattern = '^[A-Z][a-z][^:]*$'
let s:section_commit_pattern = s:section_pattern . '\|^commit '
let s:diff_header_pattern = '^diff --git \%("\=[abciow12]/.*\|/dev/null\) \%("\=[abciow12]/.*\|/dev/null\)$'

" ─── Core map wrappers ──────────────────────────────────────────────

function! spectregit#maps#Map(mode, lhs, rhs, ...) abort
  let maps = []
  let flags = a:0 && type(a:1) == type('') ? a:1 : ''
  let defer = flags =~# '<unique>'
  let flags = substitute(flags, '<unique>', '', '') . (a:rhs =~# '<Plug>' ? '' : '<script>') . '<nowait>'
  let ft = a:0 > 1 ? a:2 : 0
  for mode in split(a:mode, '\zs')
    if a:0 <= 1
      call add(maps, mode.'map <buffer>' . substitute(flags, '<unique>', '', '') . ' <Plug>fugitive:' . a:lhs . ' ' . a:rhs)
    endif
    let skip = 0
    let head = a:lhs
    let tail = ''
    let keys = get(g:, mode.'remap', {})
    if type(keys) == type([])
      continue
    endif
    while !empty(head)
      if has_key(keys, head)
        let head = keys[head]
        let skip = empty(head)
        break
      endif
      let tail = matchstr(head, '<[^<>]*>$\|.$') . tail
      let head = substitute(head, '<[^<>]*>$\|.$', '', '')
    endwhile
    if !skip && (!defer || empty(mapcheck(head.tail, mode)))
      call add(maps, mode.'map <buffer>' . flags . ' ' . head.tail . ' ' . a:rhs)
      if ft
        let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') .
              \ '|sil! exe "' . mode . 'unmap <buffer> ' . head.tail . '"'
      endif
    endif
  endfor
  exe join(maps, '|')
  return ''
endfunction

function! spectregit#maps#MapMotion(lhs, rhs) abort
  let maps = [
        \ spectregit#maps#Map('n', a:lhs, ":<C-U>" . a:rhs . "<CR>", "<silent>"),
        \ spectregit#maps#Map('o', a:lhs, ":<C-U>" . a:rhs . "<CR>", "<silent>"),
        \ spectregit#maps#Map('x', a:lhs, ":<C-U>exe 'normal! gv'<Bar>" . a:rhs . "<CR>", "<silent>")]
  call filter(maps, '!empty(v:val)')
  return join(maps, '|')
endfunction

function! spectregit#maps#MapGitOps(is_ftplugin) abort
  let ft = a:is_ftplugin
  if &modifiable
    return ''
  endif
  exe spectregit#maps#Map('n', 'c<Space>', ':Git commit<Space>', '', ft)
  exe spectregit#maps#Map('n', 'c<CR>', ':Git commit<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cv<Space>', ':tab Git commit -v<Space>', '', ft)
  exe spectregit#maps#Map('n', 'cv<CR>', ':tab Git commit -v<CR>', '', ft)
  exe spectregit#maps#Map('n', 'ca', ':<C-U>Git commit --amend<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cc', ':<C-U>Git commit<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'ce', ':<C-U>Git commit --amend --no-edit<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cw', ':<C-U>Git commit --amend --only<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cW', ':<C-U>Git commit --fixup=reword:<C-R>=spectregit#maps#SquashArgument()<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cva', ':<C-U>tab Git commit -v --amend<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cvc', ':<C-U>tab Git commit -v<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cRa', ':<C-U>Git commit --reset-author --amend<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cRe', ':<C-U>Git commit --reset-author --amend --no-edit<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cRw', ':<C-U>Git commit --reset-author --amend --only<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cf', ':<C-U>Git commit --fixup=<C-R>=spectregit#maps#SquashArgument()<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cF', ':<C-U><Bar>Git -c sequence.editor=true rebase --interactive --autosquash<C-R>=spectregit#maps#RebaseArgument()<CR><Home>Git commit --fixup=<C-R>=spectregit#maps#SquashArgument()<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cs', ':<C-U>Git commit --no-edit --squash=<C-R>=spectregit#maps#SquashArgument()<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cS', ':<C-U><Bar>Git -c sequence.editor=true rebase --interactive --autosquash<C-R>=spectregit#maps#RebaseArgument()<CR><Home>Git commit --no-edit --squash=<C-R>=spectregit#maps#SquashArgument()<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cn', ':<C-U>Git commit --edit --squash=<C-R>=spectregit#maps#SquashArgument()<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cA', ':<C-U>echoerr "Use cn"<CR>', '<silent><unique>', ft)
  exe spectregit#maps#Map('n', 'c?', ':<C-U>help fugitive_c<CR>', '<silent>', ft)

  exe spectregit#maps#Map('n', 'cr<Space>', ':Git revert<Space>', '', ft)
  exe spectregit#maps#Map('n', 'cr<CR>', ':Git revert<CR>', '', ft)
  exe spectregit#maps#Map('n', 'crc', ':<C-U>Git revert <C-R>=spectregit#maps#SquashArgument()<CR><CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'crn', ':<C-U>Git revert --no-commit <C-R>=spectregit#maps#SquashArgument()<CR><CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'cr?', ':<C-U>help fugitive_cr<CR>', '<silent>', ft)

  exe spectregit#maps#Map('n', 'cm<Space>', ':Git merge<Space>', '', ft)
  exe spectregit#maps#Map('n', 'cm<CR>', ':Git merge<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cmt', ':Git mergetool', '', ft)
  exe spectregit#maps#Map('n', 'cm?', ':<C-U>help fugitive_cm<CR>', '<silent>', ft)

  exe spectregit#maps#Map('n', 'cz<Space>', ':Git stash<Space>', '', ft)
  exe spectregit#maps#Map('n', 'cz<CR>', ':Git stash<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cza', ':<C-U>Git stash apply --quiet --index stash@{<C-R>=v:count<CR>}<CR>', '', ft)
  exe spectregit#maps#Map('n', 'czA', ':<C-U>Git stash apply --quiet stash@{<C-R>=v:count<CR>}<CR>', '', ft)
  exe spectregit#maps#Map('n', 'czp', ':<C-U>Git stash pop --quiet --index stash@{<C-R>=v:count<CR>}<CR>', '', ft)
  exe spectregit#maps#Map('n', 'czP', ':<C-U>Git stash pop --quiet stash@{<C-R>=v:count<CR>}<CR>', '', ft)
  exe spectregit#maps#Map('n', 'czs', ':<C-U>Git stash push --staged<CR>', '', ft)
  exe spectregit#maps#Map('n', 'czv', ':<C-U>exe "Gedit" fugitive#RevParse("stash@{" . v:count . "}")<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'czw', ':<C-U>Git stash push --keep-index<C-R>=v:count > 1 ? " --all" : v:count ? " --include-untracked" : ""<CR><CR>', '', ft)
  exe spectregit#maps#Map('n', 'czz', ':<C-U>Git stash push <C-R>=v:count > 1 ? " --all" : v:count ? " --include-untracked" : ""<CR><CR>', '', ft)
  exe spectregit#maps#Map('n', 'cz?', ':<C-U>help fugitive_cz<CR>', '<silent>', ft)

  exe spectregit#maps#Map('n', 'co<Space>', ':Git checkout<Space>', '', ft)
  exe spectregit#maps#Map('n', 'co<CR>', ':Git checkout<CR>', '', ft)
  exe spectregit#maps#Map('n', 'coo', ':<C-U>Git checkout <C-R>=substitute(spectregit#maps#SquashArgument(),"^$",get(spectregit#core#TempState(),"filetype","") ==# "git" ? expand("<cfile>") : "","") --<CR>', '', ft)
  exe spectregit#maps#Map('n', 'co?', ':<C-U>help fugitive_co<CR>', '<silent>', ft)

  exe spectregit#maps#Map('n', 'cb<Space>', ':Git branch<Space>', '', ft)
  exe spectregit#maps#Map('n', 'cb<CR>', ':Git branch<CR>', '', ft)
  exe spectregit#maps#Map('n', 'cb?', ':<C-U>help fugitive_cb<CR>', '<silent>', ft)

  exe spectregit#maps#Map('n', 'r<Space>', ':Git rebase<Space>', '', ft)
  exe spectregit#maps#Map('n', 'r<CR>', ':Git rebase<CR>', '', ft)
  exe spectregit#maps#Map('n', 'ri', ':<C-U>Git rebase --interactive<C-R>=spectregit#maps#RebaseArgument()<CR><CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rf', ':<C-U>Git -c sequence.editor=true rebase --interactive --autosquash<C-R>=spectregit#maps#RebaseArgument()<CR><CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'ru', ':<C-U>Git rebase --interactive @{upstream}<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rp', ':<C-U>Git rebase --interactive @{push}<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rw', ':<C-U>Git rebase --interactive<C-R>=spectregit#maps#RebaseArgument()<CR><Bar>s/^pick/reword/e<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rm', ':<C-U>Git rebase --interactive<C-R>=spectregit#maps#RebaseArgument()<CR><Bar>s/^pick/edit/e<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rd', ':<C-U>Git rebase --interactive<C-R>=spectregit#maps#RebaseArgument()<CR><Bar>s/^pick/drop/e<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rk', ':<C-U>Git rebase --interactive<C-R>=spectregit#maps#RebaseArgument()<CR><Bar>s/^pick/drop/e<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rx', ':<C-U>Git rebase --interactive<C-R>=spectregit#maps#RebaseArgument()<CR><Bar>s/^pick/drop/e<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rr', ':<C-U>Git rebase --continue<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'rs', ':<C-U>Git rebase --skip<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 're', ':<C-U>Git rebase --edit-todo<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'ra', ':<C-U>Git rebase --abort<CR>', '<silent>', ft)
  exe spectregit#maps#Map('n', 'r?', ':<C-U>help fugitive_r<CR>', '<silent>', ft)
endfunction

function! spectregit#maps#SquashArgument(...) abort
  if &filetype == 'fugitive'
    let commit = matchstr(getline('.'), '^\%(\%(\x\x\x\)\@!\l\+\s\+\)\=\zs[0-9a-f]\{4,\}\ze \|^' . s:ref_header . ': \zs\S\+')
  elseif !empty(fugitive#Result(bufnr('')))
    let commit = matchstr(getline('.'), '\S\@<!\x\{4,\}\S\@!')
  else
    let commit = s:Owner(@%)
  endif
  return len(commit) && a:0 ? printf(a:1, commit) : commit
endfunction

function! spectregit#maps#RebaseArgument() abort
  return spectregit#maps#SquashArgument(' %s^')
endfunction

function! s:Owner(path, ...) abort
  let dir = a:0 ? spectregit#core#Dir(a:1) : spectregit#core#Dir()
  if empty(dir)
    return ''
  endif
  let actualdir = FugitiveFind('.git/', dir)
  let [pdir, commit, file] = spectregit#core#DirCommitFile(a:path)
  if spectregit#core#Dir(dir) ==# spectregit#core#Dir(pdir)
    if commit =~# '^\x\{40,\}$'
      return commit
    elseif commit ==# '2'
      return '@'
    elseif commit ==# '0'
      return ''
    endif
    let merge_head = ''
    for head in ['MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD']
      if filereadable(actualdir . head)
        let merge_head = head
        break
      endif
    endfor
    if empty(merge_head)
      return ''
    endif
    if commit ==# '3'
      return merge_head
    elseif commit ==# '1'
      return spectregit#core#ChompDefault('', [dir, 'merge-base', 'HEAD', merge_head, '--'])
    endif
  endif
  let path = fnamemodify(a:path, ':p')
  if spectregit#core#cpath(actualdir, strpart(path, 0, len(actualdir))) && a:path =~# 'HEAD$'
    return strpart(path, len(actualdir))
  endif
  let refs = FugitiveFind('.git/refs', dir)
  if spectregit#core#cpath(refs . '/', path[0 : len(refs)]) && path !~# '[\/]$'
    return strpart(path, len(refs) - 4)
  endif
  return ''
endfunction

function! s:Relative(...) abort
  return spectregit#path#Path(@%, a:0 ? a:1 : ':(top)', a:0 > 1 ? a:2 : spectregit#core#Dir())
endfunction

function! s:NavigateUp(count) abort
  let dir_rev = reverse(spectregit#path#Parse(@%))
  let rev = substitute(dir_rev[1], '^$', ':', 'g')
  let c = a:count
  while c
    if rev =~# ':.*/.'
      let rev = matchstr(rev, '.*\ze/.\+', '')
    elseif rev =~# '.:.'
      let rev = matchstr(rev, '^.[^:]*:')
    elseif rev =~# '^:'
      let rev = '@^{}'
    elseif rev =~# ':$'
      let rev = rev[0:-2]
    else
      return rev.'~'.c
    endif
    let c -= 1
  endwhile
  return rev
endfunction

function! s:ParseDiffHeader(str) abort
  let list = matchlist(a:str, '\Cdiff --git \("\=\w/.*\|/dev/null\) \("\=\w/.*\|/dev/null\)$')
  if empty(list)
    let list = matchlist(a:str, '\Cdiff --git \("\=[^/].*\|/dev/null\) \("\=[^/].*\|/dev/null\)$')
  endif
  return [spectregit#core#Unquote(get(list, 1, '')), spectregit#core#Unquote(get(list, 2, ''))]
endfunction

function! s:HunkPosition(lnum) abort
  let lnum = a:lnum + get({'@': 1, '\': -1}, getline(a:lnum)[0], 0)
  let offsets = {' ': -1, '+': 0, '-': 0}
  let sigil = getline(lnum)[0]
  let line_char = sigil
  while has_key(offsets, line_char)
    let offsets[line_char] += 1
    let lnum -= 1
    let line_char = getline(lnum)[0]
  endwhile
  let starts = matchlist(getline(lnum), '^@@\+[ 0-9,-]* -\(\d\+\)\%(,\d\+\)\= +\(\d\+\)[ ,]')
  if empty(starts)
    return [0, 0, 0]
  endif
  return [lnum,
        \ sigil ==# '+' ? 0 : starts[1] + offsets[' '] + offsets['-'],
        \ sigil ==# '-' ? 0 : starts[2] + offsets[' '] + offsets['+']]
endfunction

function! s:StatusSectionFile(heading, filename) abort
  return get(get(get(get(b:, 'fugitive_status', {}), 'files', {}), a:heading, {}), a:filename, {})
endfunction

function! s:StageInfo(...) abort
  let lnum = a:0 ? a:1 : line('.')
  let sigil = matchstr(getline(lnum), '^[ @\+-]')
  let offset = -1
  if len(sigil)
    let [lnum, old_lnum, new_lnum] = s:HunkPosition(lnum)
    let offset = sigil ==# '-' ? old_lnum : new_lnum
    while getline(lnum) =~# '^[ @\+-]'
      let lnum -= 1
    endwhile
  endif
  let slnum = lnum + 1
  let heading = ''
  let index = 0
  while len(getline(slnum - 1)) && empty(heading)
    let slnum -= 1
    let heading = matchstr(getline(slnum), '^\u\l\+.\{-\}\ze (\d\++\=)$')
    if empty(heading) && getline(slnum) !~# '^[ @\+-]'
      let index += 1
    endif
  endwhile
  let text = matchstr(getline(lnum), '^[A-Z?] \zs.*')
  let file = s:StatusSectionFile(heading, text)
  let relative = get(file, 'relative', len(text) ? [text] : [])
  return {'section': matchstr(heading, '^\u\l\+'),
        \ 'heading': heading,
        \ 'sigil': sigil,
        \ 'offset': offset,
        \ 'filename': text,
        \ 'relative': copy(relative),
        \ 'paths': map(copy(relative), 'spectregit#core#Tree() . "/" . v:val'),
        \ 'commit': matchstr(getline(lnum), '^\%(\%(\x\x\x\)\@!\l\+\s\+\)\=\zs[0-9a-f]\{4,\}\ze '),
        \ 'status': matchstr(getline(lnum), '^[A-Z?]\ze \|^\%(\x\x\x\)\@!\l\+\ze [0-9a-f]'),
        \ 'submodule': get(file, 'submodule', ''),
        \ 'index': index}
endfunction

function! s:Selection(arg1, ...) abort
  if a:arg1 ==# 'n'
    let arg1 = line('.')
    let arg2 = -v:count
  elseif a:arg1 ==# 'v'
    let arg1 = line("'<")
    let arg2 = line("'>")
  else
    let arg1 = a:arg1
    let arg2 = a:0 ? a:1 : 0
  endif
  let first = arg1
  if arg2 < 0
    let last = first - arg2 - 1
  else
    let last = arg2
  endif
  if first > last
    let [first, last] = [last, first]
  endif
  return [first, last]
endfunction

function! s:CfilePorcelain(...) abort
  let tree = spectregit#core#Tree()
  if empty(tree)
    return ['']
  endif
  let lead = spectregit#core#cpath(tree, getcwd()) ? './' : tree . '/'
  let info = s:StageInfo()
  let line = getline('.')
  if len(info.sigil) && len(info.section) && len(info.paths)
    if info.section ==# 'Unstaged' && info.sigil !=# '-'
      return [lead . info.relative[0], info.offset, 'normal!zv']
    elseif info.section ==# 'Staged' && info.sigil ==# '-'
      return ['@:' . info.relative[0], info.offset, 'normal!zv']
    else
      return [':0:' . info.relative[0], info.offset, 'normal!zv']
    endif
  elseif len(info.paths)
    return [lead . info.relative[0]]
  elseif len(info.commit)
    return [info.commit]
  elseif line =~# '^' . s:ref_header . ': \|^Head: '
    return [matchstr(line, ' \zs.*')]
  else
    return ['']
  endif
endfunction

function! s:StatusCfile(...) abort
  let tree = spectregit#core#Tree()
  if empty(tree)
    return []
  endif
  let lead = spectregit#core#cpath(tree, getcwd()) ? './' : tree . '/'
  if getline('.') =~# '^.\=\trenamed:.* -> '
    return [lead . matchstr(getline('.'),' -> \zs.*')]
  elseif getline('.') =~# '^.\=\t\(\k\| \)\+\p\?: *.'
    return [lead . matchstr(getline('.'),': *\zs.\{-\}\ze\%( ([^()[:digit:]]\+)\)\=$')]
  elseif getline('.') =~# '^.\=\t.'
    return [lead . matchstr(getline('.'),'\t\zs.*')]
  elseif getline('.') =~# ': needs merge$'
    return [lead . matchstr(getline('.'),'.*\ze: needs merge$')]
  elseif getline('.') =~# '^\%(. \)\=Not currently on any branch.$'
    return ['HEAD']
  elseif getline('.') =~# '^\%(. \)\=On branch '
    return ['refs/heads/'.getline('.')[12:]]
  elseif getline('.') =~# "^\\%(. \\)\=Your branch .*'"
    return [matchstr(getline('.'),"'\\zs\\S\\+\\ze'")]
  else
    return []
  endif
endfunction

function! s:cfile() abort
  let temp_state = spectregit#core#TempState()
  let name = substitute(get(get(temp_state, 'args', []), 0, ''), '\%(^\|-\)\(\l\)', '\u\1', 'g')
  if exists('*s:' . name . 'Cfile')
    let cfile = s:{name}Cfile(temp_state)
    if !empty(cfile)
      return type(cfile) == type('') ? [cfile] : cfile
    endif
  endif
  if empty(FugitiveGitDir())
    return []
  endif
  try
    let myhash = spectregit#path#Parse(bufname(''))[0]
    if len(myhash)
      try
        let myhash = spectregit#git#RevParse(myhash)
      catch /^fugitive:/
        let myhash = ''
      endtry
    endif
    if empty(myhash) && get(temp_state, 'filetype', '') ==# 'git'
      let lnum = line('.')
      while lnum > 0
        if getline(lnum) =~# '^\%(commit\|tag\) \w'
          let myhash = matchstr(getline(lnum),'^\w\+ \zs\S\+')
          break
        endif
        let lnum -= 1
      endwhile
    endif
    let showtree = (getline(1) =~# '^tree ' && getline(2) == "")
    let commit_file = spectregit#core#DirCommitFile(bufname(''))
    let treebase = substitute(commit_file[1], '^\d$', ':&', '') . ':' .
          \ s:Relative('') . (s:Relative('') =~# '^$\|/$' ? '' : '/')
    if getline('.') =~# '^\d\{6\} \l\{3,8\} \x\{40,\}\t'
      return [treebase . spectregit#core#sub(matchstr(getline('.'),'\t\zs.*'), '/$','')]
    elseif showtree
      return [treebase . spectregit#core#sub(getline('.'), '/$','')]
    else
      let dcmds = []
      if getline('.') =~# '^\d\{6\} \x\{40,\} \d\t'
        let ref = matchstr(getline('.'),'\x\{40,\}')
        let file = ':'.spectregit#core#sub(matchstr(getline('.'),'\d\t.*'),'\t',':')
        return [file]
      endif
      if getline('.') =~# '^ref: '
        let ref = strpart(getline('.'),5)
      elseif getline('.') =~# '^\%([|/\\_ ]*\*[|/\\_ ]*\)\=commit \x\{40,\}\>'
        let ref = matchstr(getline('.'),'\x\{40,\}')
        return [ref]
      elseif getline('.') =~# '^parent \x\{40,\}\>'
        let ref = matchstr(getline('.'),'\x\{40,\}')
        return [ref]
      elseif getline('.') =~# '^tree \x\{40,\}$'
        let ref = matchstr(getline('.'),'\x\{40,\}')
        if len(myhash) && spectregit#git#RevParse(myhash.':') ==# ref
          let ref = myhash.':'
        endif
        return [ref]
      elseif getline('.') =~# '^object \x\{40,\}$' && getline(line('.')+1) =~ '^type \%(commit\|tree\|blob\)$'
        let ref = matchstr(getline('.'),'\x\{40,\}')
      elseif getline('.') =~# '^\l\{3,8\} '.myhash.'$'
        let ref = spectregit#path#Parse(bufname(''))[0]
      elseif getline('.') =~# '^\l\{3,8\} \x\{40,\}\>'
        let ref = matchstr(getline('.'),'\x\{40,\}')
        echoerr "warning: unknown context ".matchstr(getline('.'),'^\l*')
      elseif getline('.') =~# '^[A-Z]\d*\t\S' && len(myhash)
        let files = split(getline('.'), "\t")[1:-1]
        let ref = 'b/' . files[-1]
        if getline('.') =~# '^D'
          let ref = 'a/' . files[0]
        elseif getline('.') !~# '^A'
          let dcmds = ['', 'Gdiffsplit! >' . myhash . '^:' . fnameescape(files[0])]
        endif
      elseif getline('.') =~# '^[+-]'
        let [header_lnum, old_lnum, new_lnum] = s:HunkPosition(line('.'))
        if new_lnum > 0
          let ref = s:ParseDiffHeader(getline(search(s:diff_header_pattern, 'bnW')))[1]
          let dcmds = [new_lnum, 'normal!zv']
        elseif old_lnum > 0
          let ref = s:ParseDiffHeader(getline(search(s:diff_header_pattern, 'bnW')))[0]
          let dcmds = [old_lnum, 'normal!zv']
        else
          let ref = spectregit#core#Unquote(matchstr(getline('.'), '\C[+-]\{3\} \zs"\=[abciow12]/.*'))
        endif
      elseif getline('.') =~# '^rename from '
        let ref = 'a/'.getline('.')[12:]
      elseif getline('.') =~# '^rename to '
        let ref = 'b/'.getline('.')[10:]
      elseif getline('.') =~# '^@@ -\d\+\%(,\d\+\)\= +\d\+'
        let diff = getline(search(s:diff_header_pattern, 'bcnW'))
        let offset = matchstr(getline('.'), '+\zs\d\+')
        let [dref, ref] = s:ParseDiffHeader(diff)
        let dcmd = 'Gdiffsplit! +'.offset
      elseif getline('.') =~# s:diff_header_pattern
        let [dref, ref] = s:ParseDiffHeader(getline('.'))
        let dcmd = 'Gdiffsplit!'
      elseif getline('.') =~# '^index ' && getline(line('.')-1) =~# s:diff_header_pattern
        let [dref, ref] = s:ParseDiffHeader(getline(line('.') - '.'))
        let dcmd = 'Gdiffsplit!'
      elseif line('$') == 1 && getline('.') =~ '^\x\{40,\}$'
        let ref = getline('.')
      elseif expand('<cword>') =~# '^\x\{7,\}\>'
        return [expand('<cword>')]
      else
        let ref = ''
      endif
      let prefixes = {
            \ '1': '', '2': '', 'b': ':0:', 'i': ':0:', 'o': '', 'w': ''}
      if len(myhash)
        let prefixes.a = myhash.'^:'
        let prefixes.b = myhash.':'
      endif
      let ref = substitute(ref, '^\(\w\)/', '\=get(prefixes, submatch(1), "@:")', '')
      if exists('dref')
        let dref = substitute(dref, '^\(\w\)/', '\=get(prefixes, submatch(1), "@:")', '')
      endif
      if ref ==# '/dev/null'
        let ref = 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391'
      endif
      if exists('dref')
        return [ref, dcmd . ' >' . spectregit#core#fnameescape(dref)] + dcmds
      elseif ref != ""
        return [ref] + dcmds
      endif
    endif
    return []
  endtry
endfunction

function! s:GF(mode) abort
  try
    let results = &filetype ==# 'fugitive' ? s:CfilePorcelain() : &filetype ==# 'gitcommit' ? s:StatusCfile() : s:cfile()
  catch /^fugitive:/
    return 'echoerr ' . string(v:exception)
  endtry
  if len(results) > 1
    let cmd = 'G' . a:mode .
          \ (empty(results[1]) ? '' : ' +' . spectregit#core#PlusEscape(results[1])) . ' ' .
          \ spectregit#core#fnameescape(results[0])
    let tail = join(map(results[2:-1], '"|" . v:val'), '')
    if a:mode ==# 'pedit' && len(tail)
      return cmd . '|wincmd P|exe ' . string(tail[1:-1]) . '|wincmd p'
    else
      return cmd . tail
    endif
  elseif len(results) && len(results[0])
    return 'G' . a:mode . ' ' . spectregit#core#fnameescape(results[0])
  else
    return ''
  endif
endfunction

" ─── Public API ─────────────────────────────────────────────────────

function! spectregit#maps#MapCfile(...) abort
  exe 'cnoremap <buffer> <expr> <Plug><cfile>' (a:0 ? a:1 : 'fugitive#Cfile()')
  let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') . '|sil! exe "cunmap <buffer> <Plug><cfile>"'
  if !exists('g:fugitive_no_maps')
    call spectregit#maps#Map('n', 'gf',          '<SID>:find <Plug><cfile><CR>', '<silent><unique>', 1)
    call spectregit#maps#Map('n', '<C-W>f',     '<SID>:sfind <Plug><cfile><CR>', '<silent><unique>', 1)
    call spectregit#maps#Map('n', '<C-W><C-F>', '<SID>:sfind <Plug><cfile><CR>', '<silent><unique>', 1)
    call spectregit#maps#Map('n', '<C-W>gf',  '<SID>:tabfind <Plug><cfile><CR>', '<silent><unique>', 1)
    call spectregit#maps#Map('c', '<C-R><C-F>', '<Plug><cfile>', '<unique>', 1)
  endif
endfunction

function! spectregit#maps#MapJumps(...) abort
  if !&modifiable
    if get(b:, 'fugitive_type', '') ==# 'blob'
      let blame_tail = '<C-R>=v:count ? " --reverse" : ""<CR><CR>'
      exe spectregit#maps#Map('n', '<2-LeftMouse>', ':<C-U>0,1Git ++curwin blame' . blame_tail, '<silent>')
      exe spectregit#maps#Map('n', '<CR>', ':<C-U>0,1Git ++curwin blame' . blame_tail, '<silent>')
      exe spectregit#maps#Map('n', 'o',    ':<C-U>0,1Git blame' . blame_tail, '<silent>')
      exe spectregit#maps#Map('n', 'p',    ':<C-U>0,1Git! blame' . blame_tail, '<silent>')
      if has('patch-7.4.1898')
        exe spectregit#maps#Map('n', 'gO',   ':<C-U>vertical 0,1Git blame' . blame_tail, '<silent>')
        exe spectregit#maps#Map('n', 'O',    ':<C-U>tab 0,1Git blame' . blame_tail, '<silent>')
      else
        exe spectregit#maps#Map('n', 'gO',   ':<C-U>0,4Git blame' . blame_tail, '<silent>')
        exe spectregit#maps#Map('n', 'O',    ':<C-U>0,5Git blame' . blame_tail, '<silent>')
      endif
      call spectregit#maps#Map('n', 'D', ":echoerr 'fugitive: D has been removed in favor of dd'<CR>", '<silent><unique>')
      call spectregit#maps#Map('n', 'dd', ":<C-U>call spectregit#edit#DiffClose()<Bar>keepalt Gdiffsplit!<CR>", '<silent>')
      call spectregit#maps#Map('n', 'dh', ":<C-U>call spectregit#edit#DiffClose()<Bar>keepalt Ghdiffsplit!<CR>", '<silent>')
      call spectregit#maps#Map('n', 'ds', ":<C-U>call spectregit#edit#DiffClose()<Bar>keepalt Ghdiffsplit!<CR>", '<silent>')
      call spectregit#maps#Map('n', 'dv', ":<C-U>call spectregit#edit#DiffClose()<Bar>keepalt Gvdiffsplit!<CR>", '<silent>')
      call spectregit#maps#Map('n', 'd?', ":<C-U>help fugitive_d<CR>", '<silent>')
    else
      call spectregit#maps#Map('n', '<2-LeftMouse>', ':<C-U>exe <SID>GF("edit")<CR>', '<silent>')
      call spectregit#maps#Map('n', '<CR>', ':<C-U>exe <SID>GF("edit")<CR>', '<silent>')
      call spectregit#maps#Map('n', 'o',    ':<C-U>exe <SID>GF("split")<CR>', '<silent>')
      call spectregit#maps#Map('n', 'gO',   ':<C-U>exe <SID>GF("vsplit")<CR>', '<silent>')
      call spectregit#maps#Map('n', 'O',    ':<C-U>exe <SID>GF("tabedit")<CR>', '<silent>')
      call spectregit#maps#Map('n', 'p',    ':<C-U>exe <SID>GF("pedit")<CR>', '<silent>')
      if !exists('g:fugitive_no_maps')
        call spectregit#maps#Map('n', '<C-P>', ':exe <SID>PreviousItem(v:count1)<Bar>echohl WarningMsg<Bar>echo "CTRL-P is deprecated in favor of ("<Bar>echohl NONE<CR>', '<unique>')
        call spectregit#maps#Map('n', '<C-N>', ':exe <SID>NextItem(v:count1)<Bar>echohl WarningMsg<Bar>echo "CTRL-N is deprecated in favor of )"<Bar>echohl NONE<CR>', '<unique>')
      endif
      call spectregit#maps#MapMotion('(', 'exe <SID>PreviousItem(v:count1)')
      call spectregit#maps#MapMotion(')', 'exe <SID>NextItem(v:count1)')
      call spectregit#maps#MapMotion('K', 'exe <SID>PreviousHunk(v:count1)')
      call spectregit#maps#MapMotion('J', 'exe <SID>NextHunk(v:count1)')
      call spectregit#maps#MapMotion('[c', 'exe <SID>PreviousHunk(v:count1)')
      call spectregit#maps#MapMotion(']c', 'exe <SID>NextHunk(v:count1)')
      call spectregit#maps#MapMotion('[/', 'exe <SID>PreviousFile(v:count1)')
      call spectregit#maps#MapMotion(']/', 'exe <SID>NextFile(v:count1)')
      call spectregit#maps#MapMotion('[m', 'exe <SID>PreviousFile(v:count1)')
      call spectregit#maps#MapMotion(']m', 'exe <SID>NextFile(v:count1)')
      call spectregit#maps#MapMotion('[[', 'exe <SID>PreviousSection(v:count1)')
      call spectregit#maps#MapMotion(']]', 'exe <SID>NextSection(v:count1)')
      call spectregit#maps#MapMotion('[]', 'exe <SID>PreviousSectionEnd(v:count1)')
      call spectregit#maps#MapMotion('][', 'exe <SID>NextSectionEnd(v:count1)')
      call spectregit#maps#Map('no', '*', '<SID>PatchSearchExpr(0)', '<expr>')
      call spectregit#maps#Map('no', '#', '<SID>PatchSearchExpr(1)', '<expr>')
    endif
    call spectregit#maps#Map('n', 'S',    ':<C-U>echoerr "Use gO"<CR>', '<silent><unique>')
    call spectregit#maps#Map('n', 'dq', ":<C-U>call spectregit#edit#DiffClose()<CR>", '<silent>')
    call spectregit#maps#Map('n', '-', ":<C-U>exe 'Gedit ' . spectregit#core#fnameescape(<SID>NavigateUp(v:count1))<Bar> if getline(1) =~# '^tree \x\{40,\}$' && empty(getline(2))<Bar>call search('^'.escape(expand('#:t'),'.*[]~\').'/\=$','wc')<Bar>endif<CR>", '<silent>')
    call spectregit#maps#Map('n', 'P',     ":<C-U>if !v:count<Bar>echoerr 'Use ~ (or provide a count)'<Bar>else<Bar>exe 'Gedit ' . spectregit#core#fnameescape(<SID>ContainingCommit().'^'.v:count1.s:Relative(':'))<Bar>endif<CR>", '<silent>')
    call spectregit#maps#Map('n', '~',     ":<C-U>exe 'Gedit ' . spectregit#core#fnameescape(<SID>ContainingCommit().'~'.v:count1.s:Relative(':'))<CR>", '<silent>')
    call spectregit#maps#Map('n', 'C',     ":<C-U>exe 'Gedit ' . spectregit#core#fnameescape(<SID>ContainingCommit())<CR>", '<silent>')
    call spectregit#maps#Map('n', 'cp',    ":<C-U>echoerr 'Use gC'<CR>", '<silent><unique>')
    call spectregit#maps#Map('n', 'gC',    ":<C-U>exe 'Gpedit ' . spectregit#core#fnameescape(<SID>ContainingCommit())<CR>", '<silent>')
    call spectregit#maps#Map('n', 'gc',    ":<C-U>exe 'Gpedit ' . spectregit#core#fnameescape(<SID>ContainingCommit())<CR>", '<silent>')
    call spectregit#maps#Map('n', 'gi',    ":<C-U>exe 'Gsplit' (v:count ? '.gitignore' : '.git/info/exclude')<CR>", '<silent>')
    call spectregit#maps#Map('x', 'gi',    ":<C-U>exe 'Gsplit' (v:count ? '.gitignore' : '.git/info/exclude')<CR>", '<silent>')
    call spectregit#maps#Map('n', '.',     ":<C-U> <C-R>=spectregit#core#fnameescape(fugitive#Real(@%))<CR><Home>")
    call spectregit#maps#Map('x', '.',     ":<C-U> <C-R>=spectregit#core#fnameescape(fugitive#Real(@%))<CR><Home>")
    call spectregit#maps#Map('n', 'g?',    ":<C-U>help fugitive-maps<CR>", '<silent>')
    call spectregit#maps#Map('n', '<F1>',  ":<C-U>help fugitive-maps<CR>", '<silent>')
  endif
  let old_browsex = maparg('<Plug>NetrwBrowseX', 'n')
  let new_browsex = substitute(old_browsex, '\Cnetrw#CheckIfRemote(\%(netrw#GX()\)\=)', '0', 'g')
  let new_browsex = substitute(new_browsex, 'netrw#GX()\|expand((exists("g:netrw_gx")? g:netrw_gx : ''<cfile>''))', 'spectregit#maps#GX()', 'g')
  if new_browsex !=# old_browsex
    exe 'nnoremap <silent> <buffer> <Plug>NetrwBrowseX' new_browsex
  endif
  call spectregit#maps#MapGitOps(0)
endfunction

function! spectregit#maps#GX() abort
  try
    let results = &filetype ==# 'fugitive' ? s:CfilePorcelain() : &filetype ==# 'git' ? s:cfile() : []
    if len(results) && len(results[0])
      return FugitiveReal(spectregit#path#Generate(results[0]))
    endif
  catch /^fugitive:/
  endtry
  return expand(get(g:, 'netrw_gx', expand('<cfile>')))
endfunction

function! spectregit#maps#PorcelainCfile() abort
  let file = FugitiveFind(s:CfilePorcelain()[0])
  return empty(file) ? fugitive#Cfile() : spectregit#core#fnameescape(file)
endfunction

function! spectregit#maps#MessageCfile() abort
  let file = FugitiveFind(get(s:StatusCfile(), 0, ''))
  return empty(file) ? fugitive#Cfile() : spectregit#core#fnameescape(file)
endfunction

function! spectregit#maps#Cfile() abort
  let pre = ''
  let results = s:cfile()
  if empty(results)
    if !empty(spectregit#core#TempState())
      let cfile = expand('<cfile>')
      if !empty(cfile)
        return spectregit#core#fnameescape(spectregit#path#Generate(cfile))
      endif
    endif
    let cfile = expand('<cfile>')
    if &includeexpr =~# '\<v:fname\>'
      sandbox let cfile = eval(substitute(&includeexpr, '\C\<v:fname\>', '\=string(cfile)', 'g'))
    endif
    return cfile
  elseif len(results) > 1
    let pre = '+' . join(map(results[1:-1], 'escape(v:val, " ")'), '\|') . ' '
  endif
  return pre . spectregit#core#fnameescape(spectregit#path#Generate(results[0]))
endfunction

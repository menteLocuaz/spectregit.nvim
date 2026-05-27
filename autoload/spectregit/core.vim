if exists('g:autoloaded_spectregit_core') | finish | endif
let g:autoloaded_spectregit_core = 1

let s:save_cpo = &cpo
set cpo&vim

function! spectregit#core#Slash(path) abort
  if exists('+shellslash')
    return tr(a:path, '\', '/')
  endif
  return a:path
endfunction

function! spectregit#core#VimSlash(path) abort
  if exists('+shellslash')
    return tr(a:path, '\/', &shellslash ? '//' : '\\')
  endif
  return a:path
endfunction

function! spectregit#core#VimPath(path) abort
  if exists('+shellslash')
    return tr(a:path, '\/', &shellslash ? '//' : '\\')
  else
    if has('win32unix') && filereadable('/git-bash.exe')
      return substitute(a:path, '^\(\a\):', '/\l\1', '')
    else
      return a:path
    endif
  endif
endfunction

let s:fnameescape_chars = v:null
function! spectregit#core#fnameescape(file) abort
  if s:fnameescape_chars is v:null
    if has('win32')
      let s:fnameescape_chars = " \t\n*?`%#'\"|!<"
    else
      let s:fnameescape_chars = " \t\n*?[{`$\\%#'\"|!<"
    endif
  endif
  if type(a:file) == type([])
    return join(map(copy(a:file), 'spectregit#core#fnameescape(v:val)'))
  else
    return escape(a:file, s:fnameescape_chars)
  endif
endfunction

function! spectregit#core#Throw(string) abort
  throw 'fugitive: ' . a:string
endfunction

function! spectregit#core#gsub(str, pat, rep) abort
  return substitute(a:str, '\v\C' . a:pat, a:rep, 'g')
endfunction

function! spectregit#core#sub(str, pat, rep) abort
  return substitute(a:str, '\v\C' . a:pat, a:rep, '')
endfunction

function! spectregit#core#JoinChomp(list) abort
  if empty(a:list[-1])
    return join(a:list[0:-2], "\n")
  else
    return join(a:list, "\n")
  endif
endfunction

function! spectregit#core#Uniq(list) abort
  let i = 0
  let seen = {}
  while i < len(a:list)
    let str = string(a:list[i])
    if has_key(seen, str)
      call remove(a:list, i)
    else
      let seen[str] = 1
      let i += 1
    endif
  endwhile
  return a:list
endfunction

function! spectregit#core#DoAutocmd(...) abort
  return join(map(copy(a:000), "'doautocmd <nomodeline>' . v:val"), '|')
endfunction

function! spectregit#core#UrlDecode(str) abort
  return substitute(a:str, '%\(\x\x\)', '\=iconv(nr2char("0x".submatch(1)), "utf-8", "latin1")', 'g')
endfunction

function! spectregit#core#UrlEncode(str) abort
  return substitute(a:str, '[%#?&;+=\<> [:cntrl:]]', '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! spectregit#core#Unquote(string) abort
  let string = substitute(a:string, "\t*$", '', '')
  if string =~# '^".*"$'
    let unquote_chars = {
          \ 'a': "\007", 'b': "\010", 't': "\011", 'n': "\012", 'v': "\013", 'f': "\014", 'r': "\015",
          \ '"': '"', '\': '\'}
    return substitute(string[1:-2], '\\\(\o\o\o\|.\)', '\=get(unquote_chars, submatch(1), iconv(nr2char("0" . submatch(1)), "utf-8", "latin1"))', 'g')
  else
    return string
  endif
endfunction

let s:dir_commit_file = '\c^fugitive://' . (exists('+shellslash') ? '\%(/[^/]\@=\)\=\([^?#]\{-1,\}\)' : '\([^?#]\{-\}\)') . '//\%(\(\x\{40,\}\|[0-3]\)\(/[^?#]*\)\=\)\=$'

function! spectregit#core#DirCommitFile(path) abort
  let vals = matchlist(spectregit#core#Slash(a:path), s:dir_commit_file)
  if empty(vals)
    return ['', '', '']
  endif
  return [spectregit#core#Dir(spectregit#core#UrlDecode(vals[1])), vals[2], empty(vals[2]) ? '/.git/index' : spectregit#core#UrlDecode(vals[3])]
endfunction

" ─── Detection Logic ─────────────────────────────────────────────────────────

function! spectregit#core#IsGitDir(path) abort
  let path = substitute(a:path, '[\/]$', '', '') . '/'
  return len(path) && getfsize(path.'HEAD') > 10 && (isdirectory(path.'objects') && isdirectory(path.'refs') || getftype(path.'commondir') ==# 'file')
endfunction

function! s:ReadFile(path, line_count) abort
  try
    return readfile(a:path, 'b', a:line_count)
  catch
    return []
  endtry
endfunction

let s:resolved_git_dirs = {}
function! spectregit#core#ResolveGitDir(git_dir) abort
  let type = getftype(a:git_dir)
  if type ==# 'dir' && spectregit#core#IsGitDir(a:git_dir)
    return a:git_dir
  elseif type ==# 'link' && spectregit#core#IsGitDir(a:git_dir)
    return resolve(a:git_dir)
  elseif type !=# ''
    let line = get(s:ReadFile(a:git_dir, 1), 0, '')
    let file_dir = spectregit#core#Slash(spectregit#core#VimPath(matchstr(line, '^gitdir: \zs.*')))
    if file_dir !~# '^/\|^\a:\|^$' && a:git_dir =~# '/\.git$' && spectregit#core#IsGitDir(a:git_dir[0:-5] . file_dir)
      return simplify(a:git_dir[0:-5] . file_dir)
    elseif file_dir =~# '^/\|^\a:' && spectregit#core#IsGitDir(file_dir)
      return file_dir
    endif
  endif
  return ''
endfunction

function! spectregit#core#ExtractGitDir(path) abort
  if type(a:path) ==# type({})
    return get(a:path, 'fugitive_dir', get(a:path, 'git_dir', ''))
  elseif type(a:path) == type(0)
    let path = spectregit#core#Slash(a:path > 0 ? bufname(a:path) : bufname(''))
    if getbufvar(a:path, '&filetype') ==# 'netrw'
      let path = spectregit#core#Slash(getbufvar(a:path, 'netrw_curdir', path))
    endif
  else
    let path = spectregit#core#Slash(a:path)
  endif
  if path =~# '^fugitive://'
    return spectregit#path#Parse(path)[1]
  elseif empty(path)
    return ''
  endif
  let pre = substitute(matchstr(path, '^\a\a\+\ze:'), '^.', '\u&', '')
  if len(pre) && exists('*' . pre . 'Real')
    let path = {pre}Real(path)
  endif
  let root = spectregit#core#Slash(fnamemodify(path, ':p:h'))
  let previous = ""
  let env_git_dir = len($GIT_DIR) ? spectregit#core#Slash(simplify(fnamemodify(spectregit#core#VimPath($GIT_DIR), ':p:s?[\/]$??'))) : ''
  let ceiling_directories = spectregit#core#CeilingDirectories()
  while root !=# previous && root !~# '^$\|^//[^/]*$'
    if index(ceiling_directories, root) >= 0
      break
    endif
    if root ==# $GIT_WORK_TREE && spectregit#core#IsGitDir(env_git_dir)
      return env_git_dir
    endif
    let dir = substitute(root, '[\/]$', '', '') . '/.git'
    let resolved = spectregit#core#ResolveGitDir(dir)
    if !empty(resolved)
      let s:resolved_git_dirs[dir] = resolved
      return dir is# resolved || spectregit#core#Tree(resolved) is# 0 ? dir : resolved
    elseif spectregit#core#IsGitDir(root)
      let s:resolved_git_dirs[root] = root
      return root
    endif
    let previous = root
    let root = fnamemodify(root, ':h')
  endwhile
  return ''
endfunction

function! spectregit#core#CeilingDirectories() abort
  if !exists('s:ceiling_directories')
    let s:ceiling_directories = []
    let resolve = 1
    for dir in split($GIT_CEILING_DIRECTORIES, has('win32') ? ';' : ':', 1)
      if empty(dir)
        let resolve = 0
      elseif resolve
        call add(s:ceiling_directories, spectregit#core#Slash(resolve(dir)))
      else
        call add(s:ceiling_directories, spectregit#core#Slash(dir))
      endif
    endfor
  endif
  return s:ceiling_directories + get(g:, 'ceiling_directories', [spectregit#core#Slash(fnamemodify(expand('~'), ':h'))])
endfunction

function! spectregit#core#ActualDir(...) abort
  let dir = call('spectregit#core#Dir', a:000)
  if empty(dir)
    return ''
  endif
  if !has_key(s:resolved_git_dirs, dir)
    let s:resolved_git_dirs[dir] = spectregit#core#ResolveGitDir(dir)
  endif
  return empty(s:resolved_git_dirs[dir]) ? dir : s:resolved_git_dirs[dir]
endfunction

let s:commondirs = {}
function! spectregit#core#CommonDir(...) abort
  let dir = call('spectregit#core#ActualDir', a:000)
  if empty(dir)
    return ''
  endif
  if has_key(s:commondirs, dir)
    return s:commondirs[dir]
  endif
  if getfsize(dir . '/HEAD') >= 10
    let cdir = get(s:ReadFile(dir . '/commondir', 1), 0, '')
    if cdir =~# '^/\|^\a:/'
      let s:commondirs[dir] = spectregit#core#Slash(spectregit#core#VimPath(cdir))
    elseif len(cdir)
      let s:commondirs[dir] = simplify(dir . '/' . cdir)
    else
      let s:commondirs[dir] = dir
    endif
  else
    let s:commondirs[dir] = dir
  endif
  return s:commondirs[dir]
endfunction

let s:worktree_for_dir = {}
function! spectregit#core#Tree(...) abort
  let dir = call('spectregit#core#Dir', a:000)
  if empty(dir)
    return ''
  endif
  let dir = spectregit#core#ActualDir(dir)
  if !has_key(s:worktree_for_dir, dir)
    let s:worktree_for_dir[dir] = ''
    let ext_wtc_pat = 'v:val =~# "^\\s*worktreeConfig *= *\\%(true\\|yes\\|on\\|1\\) *$"'
    let config = s:ReadFile(dir . '/config', 50)
    if len(config)
      let ext_wtc_config = filter(copy(config), ext_wtc_pat)
      if len(ext_wtc_config) == 1 && filereadable(dir . '/config.worktree')
         let config += s:ReadFile(dir . '/config.worktree', 50)
      endif
    else
      let worktree = fnamemodify(spectregit#core#VimPath(get(s:ReadFile(dir . '/gitdir', 1), '0', '')), ':h')
      if worktree ==# '.'
        unlet! worktree
      endif
      if len(filter(s:ReadFile(spectregit#core#CommonDir(dir) . '/config', 50), ext_wtc_pat))
        let config = s:ReadFile(dir . '/config.worktree', 50)
      endif
    endif
    if len(config)
      let wt_config = filter(copy(config), 'v:val =~# "^\\s*worktree *="')
      if len(wt_config)
        let worktree = spectregit#core#VimPath(matchstr(wt_config[0], '= *\zs.*'))
      elseif !exists('worktree')
        call filter(config,'v:val =~# "^\\s*bare *= *true *$"')
        if empty(config)
          let s:worktree_for_dir[dir] = 0
        endif
      endif
    endif
    if exists('worktree')
      let s:worktree_for_dir[dir] = spectregit#core#Slash(resolve(worktree))
    endif
  endif
  let tree = s:worktree_for_dir[dir]
  if type(tree) == type('') && tree =~# '^\.'
    return simplify(dir . '/' . tree)
  else
    return tree
  endif
endfunction

function! spectregit#core#Dir(...) abort
  if exists('g:spectregit_test_mock_dir')
    return g:spectregit_test_mock_dir
  endif
  if v:version < 704
    return ''
  elseif !a:0 || type(a:1) == type(0) && a:1 < 0 || a:1 is# get(v:, 'true', -1)
    if exists('g:fugitive_event')
      return g:fugitive_event
    endif
    let dir = get(b:, 'git_dir', '')
    let bad_git_dir = '/$\|^fugitive:'
    if empty(dir) && (empty(bufname('')) && &filetype !=# 'netrw' || &buftype =~# '^\%(nofile\|acwrite\|quickfix\|terminal\|prompt\)$')
      return spectregit#core#ExtractGitDir(getcwd())
    elseif (!exists('b:git_dir') || b:git_dir =~# bad_git_dir) && &buftype =~# '^\%(nowrite\)\=$'
      let b:git_dir = spectregit#core#ExtractGitDir(bufnr(''))
      return b:git_dir
    endif
    return dir =~# bad_git_dir ? '' : dir
  elseif type(a:1) == type(0) && a:1 isnot# 0
    let bad_git_dir = '/$\|^fugitive:'
    if a:1 == bufnr('') && (!exists('b:git_dir') || b:git_dir =~# bad_git_dir) && &buftype =~# '^\%(nowrite\)\=$'
      let b:git_dir = spectregit#core#ExtractGitDir(a:1)
    endif
    let dir = getbufvar(a:1, 'git_dir')
    return dir =~# bad_git_dir ? '' : dir
  elseif type(a:1) == type('')
    return substitute(spectregit#core#Slash(a:1), '/$', '', '')
  elseif type(a:1) == type({})
    return get(a:1, 'fugitive_dir', get(a:1, 'git_dir', ''))
  else
    return ''
  endif
endfunction

" ─── Version & Checks ────────────────────────────────────────────────────────

function! spectregit#core#VersionCheck() abort
  if v:version < 704
    return 'return ' . string('echoerr "fugitive: Vim 7.4 or newer required"')
  elseif empty(spectregit#git#GitVersion())
    let exe = get(g:, 'fugitive_git_executable', 'git')
    if type(exe) == type([])
      let exe = get(exe, 0, 'git')
    endif
    if len(exe) && !executable(exe)
      return 'return ' . string('echoerr "fugitive: cannot find ' . string(exe) . ' in PATH"')
    endif
    return 'return ' . string('echoerr "fugitive: cannot execute Git"')
  elseif !spectregit#git#GitVersion(1, 8, 5)
    return 'return ' . string('echoerr "fugitive: Git 1.8.5 or newer required"')
  else
    if exists('b:git_dir') && empty(b:git_dir)
      unlet! b:git_dir
    endif
    return ''
  endif
endfunction

let s:worktree_error = "core.worktree is required when using an external Git dir"
function! spectregit#core#DirCheck(...) abort
  let dir = call('spectregit#core#Dir', a:000)
  if !empty(dir) && spectregit#core#Tree(dir) is# 0
    return 'return ' . string('echoerr "fugitive: ' . s:worktree_error . '"')
  elseif !empty(dir)
    return ''
  elseif empty(bufname(''))
    return 'return ' . string('echoerr "fugitive: working directory does not belong to a Git repository"')
  else
    return 'return ' . string('echoerr "fugitive: file does not belong to a Git repository"')
  endif
endfunction

" ─── Execution ───────────────────────────────────────────────────────────────

function! spectregit#core#ChompDefault(default, ...) abort
  let r = call('spectregit#git#Execute', a:000)
  return r.exit_status ? a:default : spectregit#core#JoinChomp(r.stdout)
endfunction

function! spectregit#core#LinesError(...) abort
  let r = call('spectregit#git#Execute', a:000)
  if empty(r.stdout[-1])
    call remove(r.stdout, -1)
  endif
  return [r.exit_status ? [] : r.stdout, r.exit_status]
endfunction

function! spectregit#core#TreeChomp(...) abort
  let r = call('spectregit#git#Execute', a:000)
  if !r.exit_status
    return spectregit#core#JoinChomp(r.stdout)
  endif
  throw 'fugitive: error running `' . call('spectregit#git#ShellCommand', a:000) . '`: ' . spectregit#core#JoinChomp(r.stderr)
endfunction

function! spectregit#core#StdoutToFile(out, cmd, ...) abort
  let [argv, jopts, _] = spectregit#git#PrepareJob(a:cmd)
  let exit = []
  if exists('*jobstart')
    call extend(jopts, {
          \ 'stdout_buffered': v:true,
          \ 'stderr_buffered': v:true,
          \ 'on_exit': { j, code, _ -> add(exit, code) }})
    let job = jobstart(argv, jopts)
    if a:0
      call chansend(job, a:1)
    endif
    call chanclose(job, 'stdin')
    call jobwait([job])
    if len(a:out)
      call writefile(jopts.stdout, a:out, 'b')
    endif
    return [join(jopts.stderr, "\n"), exit[0]]
  elseif exists('*ch_close_in')
    try
      let err = tempname()
      call extend(jopts, {
            \ 'out_io': len(a:out) ? 'file' : 'null',
            \ 'out_name': a:out,
            \ 'err_io': 'file',
            \ 'err_name': err,
            \ 'exit_cb': { j, code -> add(exit, code) }})
      let job = job_start(argv, jopts)
      if a:0
        call ch_sendraw(job, a:1)
      endif
      call ch_close_in(job)
      while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
        sleep 1m
      endwhile
      return [join(readfile(err, 'b'), "\n"), exit[0]]
    finally
      call delete(err)
    endtry
  elseif spectregit#core#winshell() || &shell !~# 'sh' || &shell =~# 'fish\|\%(powershell\|pwsh\)\%(\.exe\)\=$'
    throw 'fugitive: Vim 8 or higher required to use ' . &shell
  else
    let cmd = spectregit#git#ShellCommand(a:cmd)
    return call('spectregit#core#SystemError', [' (' . cmd . ' >' . (len(a:out) ? a:out : '/dev/null') . ') '] + a:000)
  endif
endfunction

" ─── Utilities ───────────────────────────────────────────────────────────────

function! spectregit#core#cpath(path, ...) abort
  if spectregit#core#FileIgnoreCase(0)
    let path = spectregit#core#VimSlash(tolower(a:path))
  else
    let path = spectregit#core#VimSlash(a:path)
  endif
  return a:0 ? path ==# spectregit#core#cpath(a:1) : path
endfunction

function! spectregit#core#FileIgnoreCase(for_completion) abort
  return (exists('+fileignorecase') && &fileignorecase)
        \ || (a:for_completion && exists('+wildignorecase') && &wildignorecase)
endfunction

function! spectregit#core#AbsoluteVimPath(...) abort
  if a:0 && type(a:1) == type('')
    let path = a:1
  else
    let path = bufname(a:0 && a:1 > 0 ? a:1 : '')
    if getbufvar(a:0 && a:1 > 0 ? a:1 : '', '&buftype') !~# '^\%(nowrite\|acwrite\)\=$'
      return path
    endif
  endif
  if spectregit#core#Slash(path) =~# '^/\|^\a\+:'
    return path
  else
    let sep = matchstr(getcwd(), '[\\/]')
    if empty(sep)
      let sep = '/'
    endif
    return getcwd() . sep . path
  endif
endfunction

function! spectregit#core#Resolve(path) abort
  let path = resolve(a:path)
  if has('win32')
    let path = spectregit#core#VimSlash(fnamemodify(fnamemodify(path, ':h'), ':p') . fnamemodify(path, ':t'))
  endif
  return path
endfunction

if !exists('s:temp_files')
  let s:temp_files = {}
endif

function! spectregit#core#TempState(...) abort
  return get(s:temp_files, spectregit#core#cpath(spectregit#core#AbsoluteVimPath(a:0 ? a:1 : -1)), {})
endfunction

function! spectregit#core#RunSave(state) abort
  let s:temp_files[spectregit#core#cpath(a:state.file)] = a:state
endfunction

function! spectregit#core#TempDelete(file) abort
  let key = spectregit#core#cpath(spectregit#core#AbsoluteVimPath(a:file))
  if has_key(s:temp_files, key) && !has_key(s:temp_files[key], 'job') && key !=# spectregit#core#cpath(get(get(g:, '_fugitive_last_job', {}), 'file', ''))
    call delete(a:file)
    call remove(s:temp_files, key)
  endif
  return ''
endfunction

function! spectregit#core#DoAutocmdChanged(dir) abort
  let dir = a:dir is# -2 ? '' : spectregit#core#Dir(a:dir)
  if empty(dir) || !exists('#User#FugitiveChanged') || exists('g:fugitive_event')
    return ''
  endif
  try
    let g:fugitive_event = dir
    if type(a:dir) == type({}) && has_key(a:dir, 'args') && has_key(a:dir, 'exit_status')
      let g:fugitive_result = a:dir
    endif
    exe spectregit#core#DoAutocmd('User FugitiveChanged')
  finally
    unlet! g:fugitive_event g:fugitive_result
    if dir isnot# spectregit#core#Dir()
      let g:fugitive_event = spectregit#core#Dir()
    endif
  endtry
  return ''
endfunction

function! spectregit#core#HasOpt(args, ...) abort
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

function! spectregit#core#LineChars(pattern) abort
  let chars = strlen(spectregit#core#gsub(matchstr(getline('.'), a:pattern), '.', '.'))
  if &conceallevel > 1
    for col in range(1, chars)
      let chars -= synconcealed(line('.'), col)[0]
    endfor
  endif
  return chars
endfunction

let s:git_index_file_env = {}
function! spectregit#core#GitIndexFileEnv() abort
  if $GIT_INDEX_FILE =~# '^/\|^\a:' && !has_key(s:git_index_file_env, $GIT_INDEX_FILE)
    let s:git_index_file_env[$GIT_INDEX_FILE] = spectregit#core#Slash(spectregit#core#VimPath($GIT_INDEX_FILE))
  endif
  return get(s:git_index_file_env, $GIT_INDEX_FILE, '')
endfunction

function! spectregit#core#Result(...) abort
  if !a:0 && exists('g:fugitive_event')
    return get(g:, 'fugitive_result', {})
  elseif !a:0 || type(a:1) == type('') && a:1 =~# '^-\=$'
    return get(g:, '_fugitive_last_job', {})
  elseif type(a:1) == type(0)
    return spectregit#core#TempState(a:1)
  elseif type(a:1) == type('')
    return spectregit#core#TempState(a:1)
  elseif type(a:1) == type({}) && has_key(a:1, 'file')
    return spectregit#core#TempState(a:1.file)
  else
    return {}
  endif
endfunction

function! spectregit#core#UsableWin(nr) abort
  return a:nr && !getwinvar(a:nr, '&previewwindow') && !getwinvar(a:nr, '&winfixwidth') &&
        \ !getwinvar(a:nr, '&winfixbuf') &&
        \ (empty(getwinvar(a:nr, 'fugitive_status')) || getbufvar(winbufnr(a:nr), 'fugitive_type') !=# 'index') &&
        \ index(['gitrebase', 'gitcommit'], getbufvar(winbufnr(a:nr), '&filetype')) < 0 &&
        \ index(['nofile','help','quickfix', 'terminal'], getbufvar(winbufnr(a:nr), '&buftype')) < 0
endfunction

function! spectregit#core#winshell() abort
  return has('win32') && &shellcmdflag !~# '^-'
endfunction

function! spectregit#core#shellesc(arg) abort
  if type(a:arg) == type([])
    return join(map(copy(a:arg), 'spectregit#core#shellesc(v:val)'))
  elseif a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  elseif spectregit#core#winshell()
    return '"' . spectregit#core#gsub(spectregit#core#gsub(a:arg, '"', '""'), '\%', '"%"') . '"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! spectregit#core#SystemError(cmd, ...) abort
  let cmd = type(a:cmd) == type([]) ? spectregit#core#shellesc(a:cmd) : a:cmd
  try
    if &shellredir ==# '>' && &shell =~# 'sh\|cmd'
      let shellredir = &shellredir
      if &shell =~# 'csh'
        set shellredir=>&
      else
        set shellredir=>%s\ 2>&1
      endif
    endif
    if exists('+guioptions') && &guioptions =~# '!'
      let guioptions = &guioptions
      set guioptions-=!
    endif
    let out = call('system', [cmd] + a:000)
    return [out, v:shell_error]
  catch /^Vim\%((\a\+)\)\=:E484:/
    let opts = ['shell', 'shellcmdflag', 'shellredir', 'shellquote', 'shellxquote', 'shellxescape', 'shellslash']
    call filter(opts, 'exists("+".v:val) && !empty(eval("&".v:val))')
    call map(opts, 'v:val."=".eval("&".v:val)')
    call spectregit#core#Throw('failed to run `' . cmd . '` with ' . join(opts, ' '))
  finally
    if exists('shellredir')
      let &shellredir = shellredir
    endif
    if exists('guioptions')
      let &guioptions = guioptions
    endif
  endtry
endfunction

function! spectregit#core#TempDeleteAll() abort
  return ''
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

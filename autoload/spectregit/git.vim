if exists('g:autoloaded_spectregit_git') | finish | endif
let g:autoloaded_spectregit_git = 1

let s:run_jobs = (exists('*ch_close_in') || exists('*jobstart')) && exists('*bufwinid')
let s:git_versions = {}
let s:temp_scripts = {}
let s:executables = {}
let s:prepare_env = {
      \ 'sequence.editor': 'GIT_SEQUENCE_EDITOR',
      \ 'core.editor': 'GIT_EDITOR',
      \ 'core.askpass': 'GIT_ASKPASS',
      \ }
let s:disable_colors = []
for s:colortype in ['advice', 'branch', 'diff', 'grep', 'interactive', 'pager', 'push', 'remote', 'showBranch', 'status', 'transport', 'ui']
  call extend(s:disable_colors, ['-c', 'color.' . s:colortype . '=false'])
endfor
unlet s:colortype

function! spectregit#git#GitVersion(...) abort
  let git = s:GitShellCmd()
  if !has_key(s:git_versions, git)
    let s:git_versions[git] = matchstr(system(git . ' --version'), '\d[^[:space:]]\+')
  endif
  if !a:0
    return s:git_versions[git]
  endif
  let components = split(s:git_versions[git], '\D\+')
  if empty(components)
    return -1
  endif
  for i in range(len(a:000))
    if a:000[i] > +get(components, i)
      return 0
    elseif a:000[i] < +get(components, i)
      return 1
    endif
  endfor
  return a:000[i] ==# get(components, i)
endfunction

function! s:GitShellCmd() abort
  if !exists('g:fugitive_git_executable')
    return 'git'
  elseif type(g:fugitive_git_executable) == type([])
    return join(map(copy(g:fugitive_git_executable), 'shellescape(v:val)'))
  else
    return g:fugitive_git_executable
  endif
endfunction

function! s:TempScript(...) abort
  let body = join(a:000, "\n")
  if !has_key(s:temp_scripts, body)
    let s:temp_scripts[body] = tempname() . '.sh'
  endif
  let temp = s:temp_scripts[body]
  if !filereadable(temp)
    call writefile(['#!/bin/sh'] + a:000, temp)
  endif
  let temp = FugitiveGitPath(temp)
  if temp =~# '\s'
    let temp = '"' . temp . '"'
  endif
  return temp
endfunction

function! spectregit#git#Autowrite() abort
  if &autowrite || &autowriteall
    try
      if &confirm
        let reconfirm = 1
        setglobal noconfirm
      endif
      silent! wall
    finally
      if exists('reconfirm')
        setglobal confirm
      endif
    endtry
  endif
  return ''
endfunction

function! spectregit#git#Wait(job_or_jobs, ...) abort
  let original = type(a:job_or_jobs) == type([]) ? copy(a:job_or_jobs) : [a:job_or_jobs]
  let jobs = map(copy(original), 'type(v:val) ==# type({}) ? get(v:val, "job", "") : v:val')
  call filter(jobs, 'type(v:val) !=# type("")')
  let timeout_ms = a:0 ? a:1 : -1
  if exists('*jobwait')
    call map(copy(jobs), 'chanclose(v:val, "stdin")')
    call jobwait(jobs, timeout_ms)
    let jobs = map(copy(original), 'type(v:val) ==# type({}) ? get(v:val, "job", "") : v:val')
    call filter(jobs, 'type(v:val) !=# type("")')
    if len(jobs)
      sleep 1m
    endif
  else
    for job in jobs
      if ch_status(job) ==# 'open'
        call ch_close_in(job)
      endif
    endfor
    let i = 0
    for job in jobs
      while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
        if i == timeout_ms
          break
        endif
        let i += 1
        sleep 1m
      endwhile
    endfor
  endif
  return a:job_or_jobs
endfunction

let s:head_cache = {}
function! spectregit#git#Head(...) abort
  let dir = a:0 > 1 ? a:2 : spectregit#core#Dir()
  if empty(dir)
    return ''
  endif
  let file = FugitiveActualDir(dir) . '/HEAD'
  let ftime = getftime(file)
  if ftime == -1
    return ''
  elseif ftime != get(s:head_cache, file, [-1])[0]
    let s:head_cache[file] = [ftime, readfile(file)[0]]
  endif
  let head = s:head_cache[file][1]
  let len = a:0 ? a:1 : 0
  if head =~# '^ref: '
    if len < 0
      return strpart(head, 5)
    else
      return substitute(head, '\C^ref: \%(refs/\%(heads/\|remotes/\|tags/\)\=\)\=', '', '')
    endif
  elseif head =~# '^\x\{40,\}$'
    return len < 0 ? head : strpart(head, 0, len)
  else
    return ''
  endif
endfunction

let s:merge_heads = ['MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD']
function! spectregit#git#CompleteHeads(dir) abort
  if empty(a:dir)
    return []
  endif
  let dir = FugitiveFind('.git/', a:dir)
  return sort(filter(['HEAD', 'FETCH_HEAD', 'ORIG_HEAD'] + s:merge_heads, 'filereadable(dir . v:val)')) +
        \ sort(spectregit#core#LinesError([a:dir, 'rev-parse', '--symbolic', '--branches', '--tags', '--remotes'])[0])
endfunction

function! spectregit#git#RevParse(rev, ...) abort
  let hash = spectregit#core#ChompDefault('', [a:0 ? a:1 : spectregit#core#Dir(), 'rev-parse', '--verify', a:rev, '--'])
  if hash =~# '^\x\{40,\}$'
    return hash
  endif
  throw 'fugitive: failed to parse revision ' . a:rev
endfunction

" ─── Shell / Service helpers (ported from monolith) ──────────────────────────

function! s:winshell() abort
  return has('win32') && &shellcmdflag !~# '^-'
endfunction

function! s:WinShellEsc(arg) abort
  if type(a:arg) == type([])
    return join(map(copy(a:arg), 's:WinShellEsc(v:val)'))
  elseif a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  else
    return '"' . spectregit#core#gsub(spectregit#core#gsub(a:arg, '"', '""'), '\%', '"%"') . '"'
  endif
endfunction

function! s:shellesc(arg) abort
  if type(a:arg) == type([])
    return join(map(copy(a:arg), 's:shellesc(v:val)'))
  elseif a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  elseif s:winshell()
    return '"' . spectregit#core#gsub(spectregit#core#gsub(a:arg, '"', '""'), '\%', '"%"') . '"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! s:executable(binary) abort
  if !has_key(s:executables, a:binary)
    let s:executables[a:binary] = executable(a:binary)
  endif
  return s:executables[a:binary]
endfunction

" ─── Git command list ────────────────────────────────────────────────────────

" Expand patterns (must match s:fnameescape being a variable, not a function)
let s:fnameescape = has('win32')
      \ ? " \t\n*?`%#'\"|!<"
      \ : " \t\n*?[{`$\\%#'\"|!<"

function! s:GitCmd() abort
  if !exists('g:fugitive_git_executable')
    return ['git']
  elseif type(g:fugitive_git_executable) == type([])
    return g:fugitive_git_executable
  else
    let dquote = '"\%([^"]\|""\|\\"\)*"\|'
    let string = g:fugitive_git_executable
    let list = []
    if string =~# '^\w\+='
      call add(list, '/usr/bin/env')
    endif
    while string =~# '\S'
      let arg = matchstr(string, '^\s*\%(' . dquote . '''[^'']*''\|\\.\|[^' . "\t" . ' |]\)\+')
      let string = strpart(string, len(arg))
      let arg = substitute(arg, '^\s\+', '', '')
      let arg = substitute(arg,
            \ '\(' . dquote . '''\%(''''\|[^'']\)*''\|\\[' . s:fnameescape . ']\|^\\[>+-]\)',
            \ '\=submatch(0)[0] ==# "\\" ? submatch(0)[1] : submatch(0)[1:-2]', 'g')
      call add(list, arg)
    endwhile
    return list
  endif
endfunction

function! s:UserCommandCwd(dir) abort
  let tree = FugitiveWorkTree(a:dir)
  return len(tree) ? spectregit#core#VimSlash(tree) : getcwd()
endfunction

" ─── Job execution ───────────────────────────────────────────────────────────

function! s:JobVimExit(dict, callback, temp, job, status) abort
  let a:dict.exit_status = a:status
  let a:dict.stderr = readfile(a:temp . '.err', 'b')
  call delete(a:temp . '.err')
  let a:dict.stdout = readfile(a:temp . '.out', 'b')
  call delete(a:temp . '.out')
  call delete(a:temp . '.in')
  call remove(a:dict, 'job')
  call call(a:callback[0], [a:dict] + a:callback[1:-1])
endfunction

function! s:JobNvimExit(dict, callback, job, data, type) dict abort
  let a:dict.stdout = self.stdout
  let a:dict.stderr = self.stderr
  let a:dict.exit_status = a:data
  call remove(a:dict, 'job')
  call call(a:callback[0], [a:dict] + a:callback[1:-1])
endfunction

function! s:JobExecute(argv, jopts, stdin, callback, ...) abort
  let dict = a:0 ? a:1 : {}
  let cb = len(a:callback) ? a:callback : [function('len')]
  if exists('*jobstart')
    call extend(a:jopts, {
          \ 'stdout_buffered': v:true,
          \ 'stderr_buffered': v:true,
          \ 'on_exit': function('s:JobNvimExit', [dict, cb])})
    try
      let dict.job = jobstart(a:argv, a:jopts)
      if !empty(a:stdin)
        call chansend(dict.job, a:stdin)
      endif
      call chanclose(dict.job, 'stdin')
    catch /^Vim\%((\a\+)\)\=:E475:/
      let [dict.exit_status, dict.stdout, dict.stderr] = [122, [''], ['']]
    endtry
  elseif exists('*ch_close_in')
    let temp = tempname()
    call extend(a:jopts, {
          \ 'out_io': 'file',
          \ 'out_name': temp . '.out',
          \ 'err_io': 'file',
          \ 'err_name': temp . '.err',
          \ 'exit_cb': function('s:JobVimExit', [dict, cb, temp])})
    if a:stdin ==# ['']
      let a:jopts.in_io = 'null'
    elseif !empty(a:stdin)
      let a:jopts.in_io = 'file'
      let a:jopts.in_name = temp . '.in'
      call writefile(a:stdin, a:jopts.in_name, 'b')
    endif
    let dict.job = job_start(a:argv, a:jopts)
    if job_status(dict.job) ==# 'fail'
      let [dict.exit_status, dict.stdout, dict.stderr] = [122, [''], ['']]
      unlet dict.job
    endif
  elseif &shell !~# 'sh' || &shell =~# 'fish\|\%(powershell\|pwsh\)\%(\.exe\)\=$'
    throw 'fugitive: Vim 8 or higher required to use ' . &shell
  else
    let cmd = s:shellesc(a:argv)
    let outfile = tempname()
    try
      if len(a:stdin)
        call writefile(a:stdin, outfile . '.in', 'b')
        let cmd = ' (' . cmd . ' >' . outfile . ' <' . outfile . '.in) '
      else
        let cmd = ' (' . cmd . ' >' . outfile . ') '
      endif
      let dict.stderr = split(system(cmd), "\n", 1)
      let dict.exit_status = v:shell_error
      let dict.stdout = readfile(outfile, 'b')
      call call(cb[0], [dict] + cb[1:-1])
    finally
      call delete(outfile)
      call delete(outfile . '.in')
    endtry
  endif
  if empty(a:callback)
    call spectregit#git#Wait(dict)
  endif
  return dict
endfunction

" ─── StdoutToFile ────────────────────────────────────────────────────────────

function! spectregit#git#StdoutToFile(out, cmd, ...) abort
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
  elseif s:winshell() || &shell !~# 'sh' || &shell =~# 'fish\|\%(powershell\|pwsh\)\%(\.exe\)\=$'
    throw 'fugitive: Vim 8 or higher required to use ' . &shell
  else
    let cmd = spectregit#git#ShellCommand(a:cmd)
    return call('s:SystemError', [' (' . cmd . ' >' . (len(a:out) ? a:out : '/dev/null') . ') '] + a:000)
  endif
endfunction

" ─── SystemError ──────────────────────────────────────────────────────────────

function! s:SystemError(cmd, ...) abort
  let cmd = type(a:cmd) == type([]) ? s:shellesc(a:cmd) : a:cmd
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
    throw 'fugitive: failed to run `' . cmd . '` with ' . join(opts, ' ')
  finally
    if exists('shellredir')
      let &shellredir = shellredir
    endif
    if exists('guioptions')
      let &guioptions = guioptions
    endif
  endtry
endfunction

" ─── PrepareEnv ──────────────────────────────────────────────────────────────

function! s:PrepareEnv(env, dir) abort
  if len($GIT_INDEX_FILE) && len(FugitiveWorkTree(a:dir)) && !has_key(a:env, 'GIT_INDEX_FILE')
    let index_dir = substitute(spectregit#core#GitIndexFileEnv(), '[^/]\+$', '', '')
    let our_dir = FugitiveFind('.git/', a:dir)
    if !spectregit#core#cpath(index_dir, our_dir) && !spectregit#core#cpath(resolve(index_dir), our_dir)
      let a:env['GIT_INDEX_FILE'] = FugitiveGitPath(FugitiveFind('.git/index', a:dir))
    endif
  endif
  if len($GIT_WORK_TREE)
    let a:env['GIT_WORK_TREE'] = '.'
  endif
endfunction

" ─── PreparePathArgs ─────────────────────────────────────────────────────────

function! s:PreparePathArgs(cmd, dir, literal, explicit) abort
  if !a:explicit
    call insert(a:cmd, '--literal-pathspecs')
  endif
  let split = index(a:cmd, '--')
  for i in range(split < 0 ? len(a:cmd) : split)
      if type(a:cmd[i]) == type(0)
        if a:literal
          let a:cmd[i] = spectregit#path#Real(bufname(a:cmd[i]))
        else
          let a:cmd[i] = fugitive#Path(bufname(a:cmd[i]), ':(top,literal)', a:dir)
        endif
      endif
  endfor
  if split < 0
    return a:cmd
  endif
  for i in range(split + 1, len(a:cmd) - 1)
    if type(a:cmd[i]) == type(0)
      if a:literal
        let a:cmd[i] = spectregit#path#Real(bufname(a:cmd[i]))
      else
        let a:cmd[i] = fugitive#Path(bufname(a:cmd[i]), ':(top,literal)', a:dir)
      endif
    elseif !a:explicit
      let a:cmd[i] = fugitive#Path(a:cmd[i], './', a:dir)
    endif
  endfor
  return a:cmd
endfunction

" ─── BuildEnvPrefix ──────────────────────────────────────────────────────────

function! s:BuildEnvPrefix(env) abort
  let pre = ''
  let env = items(a:env)
  if empty(env)
    return ''
  elseif &shell =~# '\%(powershell\|pwsh\)\%(\.exe\)\=$'
    return join(map(env, '"$Env:" . v:val[0] . " = ''" . substitute(v:val[1], "''", "''''", "g") . "''; "'), '')
  elseif s:winshell()
    return join(map(env, '"set " . substitute(join(v:val, "="), "[&|<>^]", "^^^&", "g") . "& "'), '')
  else
    return '/usr/bin/env ' . s:shellesc(map(env, 'join(v:val, "=")')) . ' '
  endif
endfunction

" ─── BuildShell ──────────────────────────────────────────────────────────────

function! s:BuildShell(dir, env, git, args) abort
  let cmd = copy(a:args)
  let tree = FugitiveWorkTree(a:dir)
  let pre = s:BuildEnvPrefix(a:env)
  if empty(tree) || index(cmd, '--') == len(cmd) - 1
    call insert(cmd, '--git-dir=' . FugitiveGitPath(a:dir))
  else
    call extend(cmd, ['-C', FugitiveGitPath(tree)], 'keep')
    if !spectregit#core#cpath(tree . '/.git', a:dir) || len($GIT_DIR)
      call extend(cmd, ['--git-dir=' . FugitiveGitPath(a:dir)], 'keep')
    endif
  endif
  return pre . join(map(a:git + cmd, 's:shellesc(v:val)'))
endfunction

" ─── JobOpts ─────────────────────────────────────────────────────────────────

function! s:JobOpts(cmd, env) abort
  if empty(a:env)
    return [a:cmd, {}]
  elseif has('patch-8.2.0239') ||
        \ has('nvim') && api_info().version.api_level - api_info().version.api_prerelease >= 7 ||
        \ has('patch-8.0.0902') && !has('nvim') && (!has('win32') || empty(filter(keys(a:env), 'exists("$" . v:val)')))
    return [a:cmd, {'env': a:env}]
  endif
  let envlist = map(items(a:env), 'join(v:val, "=")')
  if !has('win32')
    return [['/usr/bin/env'] + envlist + a:cmd, {}]
  else
    let pre = join(map(envlist, '"set " . substitute(v:val, "[&|<>^]", "^^^&", "g") . "& "'), '')
    if len(a:cmd) == 3 && a:cmd[0] ==# 'cmd.exe' && a:cmd[1] ==# '/c'
      return [a:cmd[0:1] + [pre . a:cmd[2]], {}]
    else
      return [['cmd.exe', '/c', pre . s:WinShellEsc(a:cmd)], {}]
    endif
  endif
endfunction

" ─── PrepareDirEnvGitFlagsArgs ───────────────────────────────────────────────

function! spectregit#git#PrepareDirEnvGitFlagsArgs(...) abort
  if !spectregit#git#GitVersion(1, 8, 5)
    throw 'fugitive: Git 1.8.5 or higher required'
  endif
  let git = s:GitCmd()
  if a:0 == 1 && type(a:1) == type({}) && (has_key(a:1, 'fugitive_dir') || has_key(a:1, 'git_dir')) && has_key(a:1, 'flags') && has_key(a:1, 'args')
    let cmd = a:1.flags + a:1.args
    let dir = FugitiveGitDir(a:1)
    if has_key(a:1, 'git')
      let git = a:1.git
    endif
    let env = get(a:1, 'env', {})
  else
    let list_args = []
    let cmd = []
    for l:.arg in a:000
      if type(arg) == type([])
        call extend(list_args, arg)
      else
        call add(cmd, arg)
      endif
    endfor
    call extend(cmd, list_args)
    let env = {}
  endif
  let autoenv = {}
  let explicit_pathspec_option = 0
  let literal_pathspecs = 1
  let i = 0
  let arg_count = 0
  while i < len(cmd)
    if type(cmd[i]) == type({})
      if has_key(cmd[i], 'fugitive_dir') || has_key(cmd[i], 'git_dir')
        let dir = FugitiveGitDir(cmd[i])
      endif
      if has_key(cmd[i], 'git')
        let git = cmd[i].git
      endif
      if has_key(cmd[i], 'env')
        call extend(env, cmd[i].env)
      endif
      call remove(cmd, i)
    elseif cmd[i] =~# '^$\|[\/.]' && cmd[i] !~# '^-'
      let dir = FugitiveGitDir(remove(cmd, i))
    elseif cmd[i] =~# '^--git-dir='
      let dir = FugitiveGitDir(remove(cmd, i)[10:-1])
    elseif type(cmd[i]) == type(0)
      let dir = FugitiveGitDir(remove(cmd, i))
    elseif cmd[i] ==# '-c' && len(cmd) > i + 1
      let key = matchstr(cmd[i+1], '^[^=]*')
      if has_key(s:prepare_env, tolower(key))
        let var = s:prepare_env[tolower(key)]
        let val = matchstr(cmd[i+1], '=\zs.*')
        let autoenv[var] = val
      endif
      let i += 2
    elseif cmd[i] =~# '^--.*pathspecs$'
      let literal_pathspecs = (cmd[i] ==# '--literal-pathspecs')
      let explicit_pathspec_option = 1
      let i += 1
    elseif cmd[i] !~# '^-'
      let arg_count = len(cmd) - i
      break
    else
      let i += 1
    endif
  endwhile
  if !exists('dir')
    let dir = FugitiveGitDir()
  endif
  call extend(autoenv, env)
  call s:PrepareEnv(autoenv, dir)
  if len($GPG_TTY) && !has_key(autoenv, 'GPG_TTY')
    let autoenv.GPG_TTY = ''
  endif
  call s:PreparePathArgs(cmd, dir, literal_pathspecs, explicit_pathspec_option)
  return [dir, env, extend(autoenv, env), git, cmd[0 : -arg_count-1], arg_count ? cmd[-arg_count : -1] : []]
endfunction

" ─── PrepareJob (public, port of fugitive#PrepareJob) ────────────────────────

function! s:PrepareJob(opts) abort
  let dict = {'argv': a:opts.argv}
  if has_key(a:opts, 'env')
    let dict.env = a:opts.env
  endif
  let [argv, jopts] = s:JobOpts(a:opts.argv, get(a:opts, 'env', {}))
  if has_key(a:opts, 'cwd')
    if has('patch-8.0.0902')
      let jopts.cwd = a:opts.cwd
      let dict.cwd = a:opts.cwd
    else
      throw 'fugitive: cwd unsupported'
    endif
  endif
  return [argv, jopts, dict]
endfunction

function! spectregit#git#PrepareJob(...) abort
  if a:0 == 1 && type(a:1) == type({}) && has_key(a:1, 'argv') && !has_key(a:1, 'args')
    return s:PrepareJob(a:1)
  endif
  let [repo, user_env, exec_env, git, flags, args] = call('spectregit#git#PrepareDirEnvGitFlagsArgs', a:000)
  let dir = FugitiveGitDir(repo)
  let dict = {'git': git, 'git_dir': dir, 'flags': flags, 'args': args}
  if len(user_env)
    let dict.env = user_env
  endif
  let cmd = flags + args
  let tree = FugitiveWorkTree(repo)
  if empty(tree) || index(cmd, '--') == len(cmd) - 1
    let dict.cwd = getcwd()
    call extend(cmd, ['--git-dir=' . FugitiveGitPath(dir)], 'keep')
  else
    let dict.cwd = spectregit#core#VimSlash(tree)
    call extend(cmd, ['-C', FugitiveGitPath(tree)], 'keep')
    if !spectregit#core#cpath(tree . '/.git', dir) || len($GIT_DIR)
      call extend(cmd, ['--git-dir=' . FugitiveGitPath(dir)], 'keep')
    endif
  endif
  call extend(cmd, git, 'keep')
  return s:JobOpts(cmd, exec_env) + [dict]
endfunction

" ─── PagerFor (port of fugitive#PagerFor) ────────────────────────────────────

function! spectregit#git#PagerFor(argv, ...) abort
  let args = a:argv
  if empty(args)
    return 0
  elseif (args[0] ==# 'help' || get(args, 1, '') ==# '--help') && !spectregit#core#HasOpt(args, '--web')
    return 1
  endif
  if args[0] ==# 'config' && (spectregit#core#HasOpt(args, '-e', '--edit') ||
        \   !spectregit#core#HasOpt(args, '--list', '--get-all', '--get-regexp', '--get-urlmatch')) ||
        \ args[0] =~# '^\%(tag\|branch\)$' && (
        \    spectregit#core#HasOpt(args, '--edit-description', '--unset-upstream', '-m', '-M', '--move', '-c', '-C', '--copy', '-d', '-D', '--delete') ||
        \   len(filter(args[1:-1], 'v:val =~# "^[^-]\\|^--set-upstream-to="')) &&
        \   !spectregit#core#HasOpt(args, '--contains', '--no-contains', '--merged', '--no-merged', '--points-at'))
    return 0
  endif
  let config = a:0 ? a:1 : fugitive#Config()
  let value = get(fugitive#ConfigGetAll('pager.' . args[0], config), 0, -1)
  if value =~# '^\%(true\|yes\|on\|1\)$'
    return 1
  elseif value =~# '^\%(false\|no|off\|0\|\)$'
    return 0
  elseif type(value) == type('')
    return value
  elseif args[0] =~# '^\%(branch\|config\|diff\|grep\|log\|range-diff\|shortlog\|show\|tag\|whatchanged\)$' ||
        \ (args[0] ==# 'stash' && get(args, 1, '') ==# 'show') ||
        \ (args[0] ==# 'reflog' && get(args, 1, '') !~# '^\%(expire\|delete\|exists\)$') ||
        \ (args[0] ==# 'am' && spectregit#core#HasOpt(args, '--show-current-patch'))
    return 1
  else
    return 0
  endif
endfunction

" ─── Execute (port of fugitive#Execute) ──────────────────────────────────────

function! spectregit#git#Execute(...) abort
  let cb = copy(a:000)
  let cmd = []
  let stdin = []
  while len(cb) && type(cb[0]) !=# type(function('tr'))
    if type(cb[0]) ==# type({}) && has_key(cb[0], 'stdin')
      if type(cb[0].stdin) == type([])
        call extend(stdin, cb[0].stdin)
      elseif type(cb[0].stdin) == type('')
        call extend(stdin, readfile(cb[0].stdin, 'b'))
      endif
      if len(keys(cb[0])) == 1
        call remove(cb, 0)
        continue
      endif
    endif
    call add(cmd, remove(cb, 0))
  endwhile
  let [argv, jopts, dict] = call('spectregit#git#PrepareJob', cmd)
  return s:JobExecute(argv, jopts, stdin, cb, dict)
endfunction

" ─── ShellCommand (port of fugitive#ShellCommand) ────────────────────────────

function! spectregit#git#ShellCommand(...) abort
  let [repo, _, env, git, flags, args] = call('spectregit#git#PrepareDirEnvGitFlagsArgs', a:000)
  return s:BuildShell(FugitiveGitDir(repo), env, git, flags + args)
endfunction



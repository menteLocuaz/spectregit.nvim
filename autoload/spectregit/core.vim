if exists('g:autoloaded_spectregit_core') | finish | endif
let g:autoloaded_spectregit_core = 1

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

" INTERNAL entry point used by the FugitiveGitDir() guard to prevent recursion.
function! spectregit#core#GitDirRaw(...) abort
  return call(g:Orig_FugitiveGitDir, a:000)
endfunction

" PUBLIC entry point used by all spectregit#* modules.
function! spectregit#core#Dir(...) abort
  if exists('g:spectregit_test_mock_dir')
    return g:spectregit_test_mock_dir
  endif
  return call('spectregit#core#GitDirRaw', a:000)
endfunction

function! spectregit#core#Tree(...) abort
  return call('FugitiveWorkTree', a:000)
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

function! spectregit#core#Mods(mods, ...) abort
  let mods = substitute(a:mods, '\C<mods>', '', '')
  let mods = mods =~# '\S$' ? mods . ' ' : mods
  if a:0 && mods !~# '\<\d*\%(aboveleft\|belowright\|leftabove\|rightbelow\|topleft\|botright\|tab\)\>'
    let default = a:1
    if default ==# 'Edge'
      if mods =~# '\<vertical\>' ? &splitright : &splitbelow
        let mods = 'botright ' . mods
      else
        let mods = 'topleft ' . mods
      endif
    else
      let mods = default . ' ' . mods
    endif
  endif
  return substitute(mods, '\s\+', ' ', 'g')
endfunction

function! spectregit#core#VersionCheck() abort
  if v:version < 704
    return 'return ' . string('echoerr "fugitive: Vim 7.4 or newer required"')
  elseif empty(fugitive#GitVersion())
    let exe = get(g:, 'fugitive_git_executable', 'git')
    if type(exe) == type([])
      let exe = get(exe, 0, 'git')
    endif
    if len(exe) && !executable(exe)
      return 'return ' . string('echoerr "fugitive: cannot find ' . string(exe) . ' in PATH"')
    endif
    return 'return ' . string('echoerr "fugitive: cannot execute Git"')
  elseif !fugitive#GitVersion(1, 8, 5)
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
  let dir = call('FugitiveGitDir', a:000)
  if !empty(dir) && FugitiveWorkTree(dir, 1) is# 0
    return 'return ' . string('echoerr "fugitive: ' . s:worktree_error . '"')
  elseif !empty(dir)
    return ''
  elseif empty(bufname(''))
    return 'return ' . string('echoerr "fugitive: working directory does not belong to a Git repository"')
  else
    return 'return ' . string('echoerr "fugitive: file does not belong to a Git repository"')
  endif
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

function! spectregit#core#ChompDefault(default, ...) abort
  let r = call('fugitive#Execute', a:000)
  return r.exit_status ? a:default : spectregit#core#JoinChomp(r.stdout)
endfunction

function! spectregit#core#LinesError(...) abort
  let r = call('fugitive#Execute', a:000)
  if empty(r.stdout[-1])
    call remove(r.stdout, -1)
  endif
  return [r.exit_status ? [] : r.stdout, r.exit_status]
endfunction

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

function! spectregit#core#DoAutocmd(...) abort
  return join(map(copy(a:000), "'doautocmd <nomodeline>' . v:val"), '|')
endfunction

let s:quote_chars = {
      \ "\007": 'a', "\010": 'b', "\011": 't', "\012": 'n', "\013": 'v', "\014": 'f', "\015": 'r',
      \ '"': '"', '\': '\'}

let s:unquote_chars = {
      \ 'a': "\007", 'b': "\010", 't': "\011", 'n': "\012", 'v': "\013", 'f': "\014", 'r': "\015",
      \ '"': '"', '\': '\'}

function! spectregit#core#Quote(string) abort
  let string = substitute(a:string, "[\001-\037\"\\\177]", '\="\\" . get(s:quote_chars, submatch(0), printf("%03o", char2nr(submatch(0))))', 'g')
  if string !=# a:string
    return '"' . string . '"'
  else
    return string
  endif
endfunction

function! spectregit#core#Unquote(string) abort
  let string = substitute(a:string, "\t*$", '', '')
  if string =~# '^".*"$'
    return substitute(string[1:-2], '\\\(\o\o\o\|.\)', '\=get(s:unquote_chars, submatch(1), iconv(nr2char("0" . submatch(1)), "utf-8", "latin1"))', 'g')
  else
    return string
  endif
endfunction

if exists('+shellslash')
  let s:dir_commit_file = '\c^fugitive://\%(/[^/]\@=\)\=\([^?#]\{-1,\}\)//\%(\(\x\{40,\}\|[0-3]\)\(/[^?#]*\)\=\)\=$'
else
  let s:dir_commit_file = '\c^fugitive://\([^?#]\{-\}\)//\%(\(\x\{40,\}\|[0-3]\)\(/[^?#]*\)\=\)\=$'
endif

function! spectregit#core#DirCommitFile(path) abort
  let vals = matchlist(spectregit#core#Slash(a:path), s:dir_commit_file)
  if empty(vals)
    return ['', '', '']
  endif
  return [spectregit#core#Dir(fugitive#UrlDecode(vals[1])), vals[2], empty(vals[2]) ? '/.git/index' : fugitive#UrlDecode(vals[3])]
endfunction

function! spectregit#core#ArgSplit(string) abort
  let string = a:string
  let args = []
  while string =~# '\S'
    let arg = matchstr(string, '^\s*\%(\\.\|\S\)\+')
    let string = strpart(string, len(arg))
    let arg = substitute(arg, '^\s\+', '', '')
    call add(args, substitute(arg, '\\\+[|" ]', '\=submatch(0)[len(submatch(0))/2 : -1]', 'g'))
  endwhile
  return args
endfunction

function! spectregit#core#TreeChomp(...) abort
  let r = call('fugitive#Execute', a:000)
  if !r.exit_status
    return spectregit#core#JoinChomp(r.stdout)
  endif
  throw 'fugitive: error running `' . call('fugitive#ShellCommand', a:000) . '`: ' . spectregit#core#JoinChomp(r.stderr)
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
  let dir = a:dir is# -2 ? '' : FugitiveGitDir(a:dir)
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
    if dir isnot# FugitiveGitDir()
      let g:fugitive_event = FugitiveGitDir()
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

function! spectregit#core#UsableWin(nr) abort
  return a:nr && !getwinvar(a:nr, '&previewwindow') && !getwinvar(a:nr, '&winfixwidth') &&
        \ !getwinvar(a:nr, '&winfixbuf') &&
        \ (empty(getwinvar(a:nr, 'fugitive_status')) || getbufvar(winbufnr(a:nr), 'fugitive_type') !=# 'index') &&
        \ index(['gitrebase', 'gitcommit'], getbufvar(winbufnr(a:nr), '&filetype')) < 0 &&
        \ index(['nofile','help','quickfix', 'terminal'], getbufvar(winbufnr(a:nr), '&buftype')) < 0
endfunction

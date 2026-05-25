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

function! spectregit#core#Dir(...) abort
  return call('FugitiveGitDir', a:000)
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

function! spectregit#core#UsableWin(nr) abort
  return a:nr && !getwinvar(a:nr, '&previewwindow') && !getwinvar(a:nr, '&winfixwidth') &&
        \ !getwinvar(a:nr, '&winfixbuf') &&
        \ (empty(getwinvar(a:nr, 'fugitive_status')) || getbufvar(winbufnr(a:nr), 'fugitive_type') !=# 'index') &&
        \ index(['gitrebase', 'gitcommit'], getbufvar(winbufnr(a:nr), '&filetype')) < 0 &&
        \ index(['nofile','help','quickfix', 'terminal'], getbufvar(winbufnr(a:nr), '&buftype')) < 0
endfunction

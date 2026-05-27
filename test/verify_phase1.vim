" test/verify_phase1.vim

let s:root = expand('<sfile>:p:h:h')
execute 'set rtp+=' . fnameescape(s:root)

let s:log_file = s:root . '/verify_log.txt'
call writefile(["Starting Phase 1 verification..."], s:log_file)

function! Log(msg) abort
  call writefile([a:msg], g:verify_log_file, "a")
endfunction
let g:verify_log_file = s:log_file

" Force load modules
runtime autoload/spectregit/core.vim
runtime autoload/spectregit/path.vim
runtime autoload/spectregit/git.vim
runtime autoload/spectregit/config.vim

function! s:assert(cond, msg) abort
  if !a:cond
    call Log('Assertion failed: ' . a:msg)
    echoerr 'Assertion failed: ' . a:msg
    cquit 1
  endif
endfunction

try
  let tempdir = tempname()
  call mkdir(tempdir, 'p')
  let prev_cwd = getcwd()
  execute 'cd' fnameescape(tempdir)
  call Log('Temp dir: ' . tempdir)
  
  call system('git init -q')
  call system('git config user.email "test@example.com"')
  call system('git config user.name "Test User"')
  call writefile(['hello'], 'test.txt')
  call system('git add test.txt')
  call system('git commit -q -m "initial"')
  
  let git_dir = finddir('.git', tempdir . ';')
  let head = trim(system('git rev-parse HEAD'))
  call Log('Git dir: ' . git_dir)
  call Log('HEAD: ' . head)

  " ─── Core Detection ───
  call Log('Testing Core Detection...')
  call s:assert(spectregit#core#Dir() ==# simplify(tempdir . '/.git'), 'spectregit#core#Dir() failed')
  call s:assert(spectregit#core#IsGitDir(tempdir . '/.git'), 'IsGitDir failed')
  call s:assert(spectregit#core#Tree() ==# simplify(tempdir), 'spectregit#core#Tree() failed')

  " ─── Path Find ───
  call Log('Testing Path Find...')
  let found = spectregit#path#Find('.git/config')
  call s:assert(found =~# 'config$', 'spectregit#path#Find() failed')

  " ─── Path IO ───
  call Log('Testing Path IO...')
  let url = 'fugitive://' . git_dir . '//' . head . '/test.txt'
  call s:assert(spectregit#path#getftime(url) > 0, 'getftime failed')
  call s:assert(spectregit#path#getfsize(url) == 6, 'getfsize failed')
  call s:assert(spectregit#path#getftype(url) ==# 'file', 'getftype failed')
  call s:assert(spectregit#path#readfile(url) == ['hello'], 'readfile failed')

  " ─── Write & Delete ───
  call Log('Testing Write & Delete...')
  let url_new = 'fugitive://' . git_dir . '//0/new.txt'
  
  sleep 2
  let res_write = spectregit#path#writefile(['world'], url_new)
  call Log('writefile result: ' . res_write)
  call s:assert(res_write == 0, 'writefile failed')
  
  sleep 2
  let read_back = spectregit#path#readfile(url_new)
  call Log('readfile result: ' . string(read_back))
  call s:assert(read_back == ['world'], 'readfile after write failed')
  
  call s:assert(spectregit#path#delete(url_new) == 0, 'delete failed')
  call s:assert(len(spectregit#core#LinesError([git_dir, 'ls-files', '--', 'new.txt'])[0]) == 0, 'file still in index after delete')

  " ─── Remote & SSH ───
  call Log('Testing Remote & SSH...')
  call s:assert(spectregit#config#SshHostAlias('git@github.com') ==# 'git@github.com', 'SshHostAlias failed')
  let resolved = spectregit#config#RemoteResolve('file:///tmp/repo', [])
  call s:assert(resolved.scheme ==# 'file', 'RemoteResolve scheme failed')

  let success_file = s:root . '/verify_success.txt'
  call writefile(["Phase 1 verification successful!"], success_file)
  call Log('Phase 1 verification successful!')
catch
  call Log('EXCEPTION: ' . v:exception)
  call Log('THROWPOINT: ' . v:throwpoint)
  echoerr v:exception
  echoerr v:throwpoint
  cquit 1
finally
  execute 'cd' fnameescape(prev_cwd)
endtry
q!

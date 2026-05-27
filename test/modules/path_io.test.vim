" test/modules/path_io.test.vim

let s:suite = themis#suite('Module: Path IO')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort
  let self.tempdir = tempname()
  call mkdir(self.tempdir, 'p')
  let self.prev_cwd = getcwd()
  execute 'cd' fnameescape(self.tempdir)
  call system('git init -q')
  call system('git config user.email "test@example.com"')
  call system('git config user.name "Test User"')
  call writefile(['hello'], 'test.txt')
  call system('git add test.txt')
  call system('git commit -q -m "initial"')
  let self.git_dir = finddir('.git', self.tempdir . ';')
  let self.head = trim(system('git rev-parse HEAD'))
endfunction

function! s:suite.after_each() abort
  execute 'cd' fnameescape(self.prev_cwd)
  if has('win32')
    call system('rd /s /q ' . shellescape(self.tempdir))
  else
    call system('rm -rf ' . shellescape(self.tempdir))
  endif
endfunction

function! s:suite.test_getftime() abort
  let url = 'fugitive://' . self.git_dir . '//' . self.head . '/test.txt'
  let ftime = spectregit#path#getftime(url)
  call s:assert.type_number(ftime)
  call s:assert.true(ftime > 0)
endfunction

function! s:suite.test_getfsize() abort
  let url = 'fugitive://' . self.git_dir . '//' . self.head . '/test.txt'
  let fsize = spectregit#path#getfsize(url)
  call s:assert.equals(fsize, 6)
endfunction

function! s:suite.test_getftype() abort
  let url = 'fugitive://' . self.git_dir . '//' . self.head . '/test.txt'
  call s:assert.equals(spectregit#path#getftype(url), 'file')

  let url_dir = 'fugitive://' . self.git_dir . '//' . self.head . '/'
  call s:assert.equals(spectregit#path#getftype(url_dir), 'dir')
endfunction

function! s:suite.test_filereadable() abort
  let url = 'fugitive://' . self.git_dir . '//' . self.head . '/test.txt'
  call s:assert.true(spectregit#path#filereadable(url))
  call s:assert.false(spectregit#path#filereadable(url . 'nonexistent'))
endfunction

function! s:suite.test_filewritable() abort
  " For fugitive URLs, filewritable generally returns 1 for blobs if index is writable
  let url = 'fugitive://' . self.git_dir . '//0/test.txt'
  call s:assert.equals(spectregit#path#filewritable(url), 1)
endfunction

function! s:suite.test_isdirectory() abort
  let url_dir = 'fugitive://' . self.git_dir . '//' . self.head . '/'
  call s:assert.true(spectregit#path#isdirectory(url_dir))
  let url_file = 'fugitive://' . self.git_dir . '//' . self.head . '/test.txt'
  call s:assert.false(spectregit#path#isdirectory(url_file))
endfunction

function! s:suite.test_readfile_writefile() abort
  let url = 'fugitive://' . self.git_dir . '//0/new_file.txt'
  call s:assert.equals(spectregit#path#writefile(['new line'], url), 0)
  
  let lines = spectregit#path#readfile(url)
  call s:assert.equals(lines, ['new line'])
endfunction

function! s:suite.test_glob() abort
  let url = 'fugitive://' . self.git_dir . '//' . self.head . '/test*'
  let matches = spectregit#path#glob(url)
  call s:assert.equals(len(matches), 1)
  call s:assert.true(matches[0] =~# 'test.txt$')
endfunction

function! s:suite.test_delete() abort
  let url = 'fugitive://' . self.git_dir . '//0/test.txt'
  call s:assert.equals(spectregit#path#delete(url), 0)
  " Verify it's gone from index
  let [lines, err] = spectregit#core#LinesError([self.git_dir, 'ls-files', '--', 'test.txt'])
  call s:assert.equals(len(lines), 0)
endfunction

function! s:suite.test_simplify_resolve() abort
  let url = 'fugitive://' . self.git_dir . '//' . self.head . '/./test.txt'
  let simplified = spectregit#path#simplify(url)
  call s:assert.true(simplified =~# 'test.txt$')
  call s:assert.false(simplified =~# '/\./')
  
  let resolved = spectregit#path#resolve(url)
  call s:assert.equals(resolved, simplified)
endfunction

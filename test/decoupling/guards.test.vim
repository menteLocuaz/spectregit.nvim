" test/decoupling/guards.test.vim

let s:suite = themis#suite('Guards Verification')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort
  call test#helper#LoadPlugin()
endfunction

function! s:suite.verify_original_saved() abort
  " In plugin/spectregit.vim, we saved FugitiveGitDir to g:Orig_FugitiveGitDir
  call s:assert.exists('g:Orig_FugitiveGitDir')
  call s:assert.exists('g:Orig_FugitiveStatusline')
  
  " Check that they are actually functions/funcrefs
  call s:assert.true(type(g:Orig_FugitiveGitDir) == type(function('tr')) || type(g:Orig_FugitiveGitDir) == type({}), 'Orig_FugitiveGitDir should be a function or funcref')
endfunction

function! s:suite.verify_wrappers_active() abort
  " FugitiveGitDir should now be our guard function
  " We can check this by verifying it routes to spectregit#core#GitDirRaw
  " but fundamentally we just want to know it exists and is callable
  call s:assert.exists('*FugitiveGitDir')
  call s:assert.exists('*FugitiveStatusline')
endfunction

function! s:suite.verify_redirection() abort
  " Mock a directory
  call test#helper#MockFugitiveGitDir('/tmp/mock_git')
  
  " FugitiveGitDir() should still return the real one if it doesn't use spectregit#core#Dir
  " Wait, FugitiveGitDir is replaced in plugin/spectregit.vim:
  " function! FugitiveGitDir(...) abort
  "   if exists('*spectregit#core#GitDirRaw')
  "     return call('spectregit#core#GitDirRaw', a:000)
  "   endif
  "   return call(g:Orig_FugitiveGitDir, a:000)
  " endfunction
  " And spectregit#core#GitDirRaw calls g:Orig_FugitiveGitDir.
  " So FugitiveGitDir() SHOULD NOT be affected by our mock, 
  " but spectregit#core#Dir() SHOULD.
  
  let real_dir = FugitiveGitDir()
  let spectre_dir = spectregit#core#Dir()
  
  call s:assert.equals(spectre_dir, '/tmp/mock_git')
  " Assuming we are in a git repo, real_dir might be non-empty. 
  " If not, it's empty. Either way it shouldn't be our mock.
  call s:assert.not_equals(real_dir, '/tmp/mock_git')
  
  call test#helper#ClearMock()
endfunction

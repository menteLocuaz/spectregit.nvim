" test/modules/repo.test.vim

let s:suite = themis#suite('Module: Repo')
let s:assert = themis#helper('assert')

function! s:suite.test_get_repo() abort
  call test#helper#MockFugitiveGitDir('/tmp/mock_git')
  let repo = spectregit#repo#Get()
  call s:assert.equals(repo.git_dir, '/tmp/mock_git')
  call test#helper#ClearMock()
endfunction

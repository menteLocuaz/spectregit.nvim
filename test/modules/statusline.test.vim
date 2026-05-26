" test/modules/statusline.test.vim

let s:suite = themis#suite('Module: Statusline')
let s:assert = themis#helper('assert')

function! s:suite.test_get() abort
  call test#helper#MockFugitiveGitDir('/tmp/mock_git')
  " We can't easily test the full output without a real git repo or more mocks,
  " but we can verify it doesn't crash and returns a string.
  let res = spectregit#statusline#Get()
  call s:assert.true(type(res) == type(''))
  call test#helper#ClearMock()
endfunction

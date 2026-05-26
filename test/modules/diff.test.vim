" test/modules/diff.test.vim

let s:suite = themis#suite('Module: Diff')
let s:assert = themis#helper('assert')

function! s:suite.test_diff_interface() abort
  " Test that Diffsplit exists
  call s:assert.equals(exists('*spectregit#diff#Diffsplit'), 1)
endfunction

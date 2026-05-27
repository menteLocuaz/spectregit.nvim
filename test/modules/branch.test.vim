" test/modules/branch.test.vim

let s:suite = themis#suite('Module: Branch')
let s:assert = themis#helper('assert')

function! s:suite.test_branch_create_interface() abort
  call s:assert.equals(exists('*spectregit#branch#Create'), 1)
endfunction

" test/modules/edit.test.vim

let s:suite = themis#suite('Module: Edit')
let s:assert = themis#helper('assert')

function! s:suite.test_edit_interface() abort
  " Test that Open exists
  call s:assert.equals(exists('*spectregit#edit#Open'), 1)
endfunction

" test/modules/quickfix.test.vim

let s:suite = themis#suite('Module: Quickfix')
let s:assert = themis#helper('assert')

function! s:suite.test_cwindow() abort
  " Just verify it exists and is callable
  call s:assert.exists('*spectregit#quickfix#Cwindow')
endfunction

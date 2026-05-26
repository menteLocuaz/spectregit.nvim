" test/modules/fold.test.vim

let s:suite = themis#suite('Module: Fold')
let s:assert = themis#helper('assert')

function! s:suite.test_foldtext_default() abort
  set foldmethod=manual
  let res = spectregit#fold#Foldtext()
  call s:assert.equals(res, foldtext())
endfunction

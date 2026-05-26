" test/modules/write.test.vim

let s:suite = themis#suite('Module: Write')
let s:assert = themis#helper('assert')

function! s:suite.test_write_interface() abort
  " Test that WriteCommand exists
  call s:assert.equals(exists('*spectregit#write#WriteCommand'), 1)
endfunction

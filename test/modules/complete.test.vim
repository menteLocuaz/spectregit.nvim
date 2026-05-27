" test/modules/complete.test.vim

let s:suite = themis#suite('Module: Complete')
let s:assert = themis#helper('assert')

function! s:suite.test_filter_escape() abort
  let items = ['file 1.txt', 'file[2].txt']
  let res = spectregit#complete#FilterEscape(items, 'file')
  if v:version >= 902
    call s:assert.equals(res, ['file\ 1.txt', 'file\[2].txt'])
  else
    call s:assert.equals(res, ['file\ 1.txt', 'file\[2\].txt'])
  endif
endfunction

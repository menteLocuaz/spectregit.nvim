" test/modules/statusline.test.vim

let s:suite = themis#suite('Module: Statusline')
let s:assert = themis#helper('assert')

function! s:suite.test_statusline_get() abort
  let status = spectregit#statusline#Get()
  call s:assert.is_string(status)
endfunction

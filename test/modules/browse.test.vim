" test/modules/browse.test.vim

let s:suite = themis#suite('Module: Browse')
let s:assert = themis#helper('assert')

function! s:suite.test_browse_url_interface() abort
  " Test the interface of spectregit#browse#UrlEncode
  let encoded = spectregit#browse#UrlEncode('foo bar')
  call s:assert.equals(encoded, 'foo%20bar')
endfunction

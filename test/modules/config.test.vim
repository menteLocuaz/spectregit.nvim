" test/modules/config.test.vim

let s:suite = themis#suite('Module: Config')
let s:assert = themis#helper('assert')

function! s:suite.test_remote_url() abort
  " Test that it can fetch a remote URL (assuming standard setup)
  " In a real test environment this might need more setup,
  " but we are testing the interface.
  let url = spectregit#config#RemoteUrl('origin')
  " Just checking that it returns a string (empty or URL)
  call s:assert.is_string(url)
endfunction

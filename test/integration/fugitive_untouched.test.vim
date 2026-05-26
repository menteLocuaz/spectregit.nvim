" test/integration/fugitive_untouched.test.vim

let s:suite = themis#suite('Integrity: Fugitive Untouched')
let s:assert = themis#helper('assert')

function! s:suite.test_checksum() abort
  " Expected SHA256 of autoload/fugitive.vim at the start of implementation
  let l:expected_sha = 'f25e8718fd1ef02368031f67bf227524caeaa2008b88973b7039e1dddd7417af'
  
  if executable('sha256sum')
    let l:output = system('sha256sum autoload/fugitive.vim')
    let l:actual_sha = split(l:output, ' ')[0]
    call s:assert.equals(l:actual_sha, l:expected_sha, 'autoload/fugitive.vim SHOULD NOT be modified by the Strangler Fig pattern')
  else
    call s:suite.skip('sha256sum not found in environment')
  endif
endfunction

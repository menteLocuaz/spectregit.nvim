" test/helper.vim - Shared setup and mocking utilities

function! test#helper#LoadPlugin() abort
  " Ensure the plugin is loaded
  runtime! plugin/spectregit.vim
  runtime! plugin/fugitive.vim
endfunction

function! test#helper#MockFugitiveGitDir(val) abort
  let g:spectregit_test_mock_dir = a:val
  " In a real implementation, spectregit#core#Dir() might check this global
endfunction

function! test#helper#ClearMock() abort
  unlet! g:spectregit_test_mock_dir
endfunction

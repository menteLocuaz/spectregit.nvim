" test/decoupling/fallback.test.vim
" Fallback logic: spectregit functions exist and are callable.
" Original fugitive functions remain available.

let s:suite = themis#suite('Fallback Logic')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort
  call test#helper#LoadPlugin()
endfunction

function! s:suite.verify_spectregit_statusline() abort
  call s:assert.exists('*spectregit#statusline#Get')

  " Call without git dir — should not throw, returns empty
  try
    call spectregit#statusline#Get()
    call s:assert.true(1, 'spectregit#statusline#Get callable')
  catch
    call s:assert.fail('spectregit#statusline#Get threw: ' . v:exception)
  endtry
endfunction

function! s:suite.verify_fugitive_statusline_available() abort
  " Original fugitive functions are still callable
  call s:assert.exists('*fugitive#Execute')
  call s:assert.exists('*fugitive#RevParse')
endfunction

" test/modules/core.test.vim

let s:suite = themis#suite('Module: Core')
let s:assert = themis#helper('assert')

function! s:suite.test_slash() abort
  if exists('+shellslash')
    call s:assert.equals(spectregit#core#Slash('C:\path\to\file'), 'C:/path/to/file')
  else
    call s:assert.equals(spectregit#core#Slash('path/to/file'), 'path/to/file')
  endif
endfunction

function! s:suite.test_fnameescape() abort
  call s:assert.equals(spectregit#core#fnameescape('file name.txt'), 'file\ name.txt')
  call s:assert.equals(spectregit#core#fnameescape('file[1].txt'), 'file\[1\].txt')
endfunction

function! s:suite.test_argsplit() abort
  let args = spectregit#core#ArgSplit('++opt +cmd file1 file2')
  call s:assert.equals(args, ['++opt', '+cmd', 'file1', 'file2'])
endfunction

function! s:suite.test_mock_dir() abort
  call test#helper#MockFugitiveGitDir('/tmp/mock')
  call s:assert.equals(spectregit#core#Dir(), '/tmp/mock')
  call test#helper#ClearMock()
endfunction

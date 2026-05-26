" test/modules/cd.test.vim

let s:suite = themis#suite('Module: CD')
let s:assert = themis#helper('assert')

function! s:suite.test_cd_path() abort
  call test#helper#MockFugitiveGitDir('/tmp/mock_git')
  let res = spectregit#cd#Cd('/some/path')
  call s:assert.match(res, '^cd ')
  call test#helper#ClearMock()
endfunction

function! s:suite.test_lcd_path() abort
  call test#helper#MockFugitiveGitDir('/tmp/mock_git')
  let res = spectregit#cd#Lcd('/some/path')
  call s:assert.match(res, '^lcd ')
  call test#helper#ClearMock()
endfunction

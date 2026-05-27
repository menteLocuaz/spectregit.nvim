" test/decoupling/guards.test.vim
" Note: The original guard/redefinition pattern was rejected (see AGENTS.md).
" These tests verify the current architecture: no function redefinition.

let s:suite = themis#suite('Guards Verification')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort
  call test#helper#LoadPlugin()
endfunction

function! s:suite.verify_fugitive_untouched() abort
  " Fugitive functions remain as-is (no redefinition)
  call s:assert.exists('*fugitive#Execute')
  call s:assert.exists('*fugitive#Find')
endfunction

function! s:suite.verify_spectregit_core_dir() abort
  " spectregit#core#Dir is our replacement
  call s:assert.exists('*spectregit#core#Dir')
endfunction

function! s:suite.verify_mock_redirection() abort
  call test#helper#MockFugitiveGitDir('/tmp/mock_git')
  let spectre_dir = spectregit#core#Dir()
  call s:assert.equals(spectre_dir, '/tmp/mock_git')
  call test#helper#ClearMock()
endfunction

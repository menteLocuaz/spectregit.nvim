if exists('g:autoloaded_spectregit_compat') | finish | endif
let g:autoloaded_spectregit_compat = 1

let s:save_cpo = &cpo
set cpo&vim

" Wrappers for Fugitive* global functions defined in plugin/fugitive.vim.
" These exist so spectregit modules don't depend directly on fugitive's
" global namespace. Replace with native spectregit implementations as
" each module is fully ported.

function! spectregit#compat#GitDir(...) abort
  return call('FugitiveGitDir', a:000)
endfunction

function! spectregit#compat#Find(...) abort
  return call('FugitiveFind', a:000)
endfunction

function! spectregit#compat#Real(...) abort
  return call('FugitiveReal', a:000)
endfunction

function! spectregit#compat#ConfigGet(name, ...) abort
  return call('FugitiveConfigGet', [a:name] + a:000)
endfunction

function! spectregit#compat#Config(name, ...) abort
  return call('FugitiveConfig', [a:name] + a:000)
endfunction

function! spectregit#compat#ConfigGetAll(name, ...) abort
  return call('FugitiveConfigGetAll', [a:name] + a:000)
endfunction

function! spectregit#compat#GitPath(path) abort
  return FugitiveGitPath(a:path)
endfunction

function! spectregit#compat#ExtractGitDir(path) abort
  return FugitiveExtractGitDir(a:path)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

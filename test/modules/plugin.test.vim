" test/modules/plugin.test.vim

let s:suite = themis#suite('Plugin Registration')
let s:assert = themis#helper('assert')

function! s:suite.before() abort
  runtime! plugin/fugitive.vim
  runtime! plugin/spectregit.vim
endfunction

function! s:suite.test_commands_exist() abort
  call s:assert.equals(exists(':Gcd'), 2, 'Gcd command should be registered')
  call s:assert.equals(exists(':Gedit'), 2, 'Gedit command should be registered')
  call s:assert.equals(exists(':Gwrite'), 2, 'Gwrite command should be registered')
  call s:assert.equals(exists(':Gstatus'), 2, 'Gstatus command should be registered')
  call s:assert.equals(exists(':Gblame'), 2, 'Gblame command should be registered')
endfunction

function! s:suite.test_autocmds_exist() abort
  let l:autocmds = execute('autocmd spectregit_bufread')
  call s:assert.match(l:autocmds, 'BufReadCmd.*fugitive://\*', 'BufReadCmd should be registered')
  
  let l:autocmds = execute('autocmd spectregit_status')
  call s:assert.match(l:autocmds, 'BufWritePost', 'BufWritePost should be registered')
  
  let l:autocmds = execute('autocmd spectregit_temp')
  call s:assert.match(l:autocmds, 'BufReadPre', 'BufReadPre should be registered')
endfunction

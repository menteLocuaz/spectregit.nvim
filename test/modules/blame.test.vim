" test/modules/blame.test.vim

let s:suite = themis#suite('Module: Blame')
let s:assert = themis#helper('assert')

function! s:suite.test_subcommand() abort
  try
    call spectregit#blame#Subcommand(1, 1, 0, 0, 0, {"subcommand": "blame", "flags": [], "subcommand_args": [], "mods": ""})
  catch
    call s:assert.fail('Subcommand failed: ' . v:exception)
  endtry
endfunction

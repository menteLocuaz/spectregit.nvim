" test/decoupling/commands.test.vim

let s:suite = themis#suite('Command Routing')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort
  call test#helper#LoadPlugin()
endfunction

function! s:suite.verify_commands_exist() abort
  let commands = [
        \ 'Gedit', 'Gsplit', 'Gvsplit', 'Gtabedit', 'Gpedit', 'Gdrop',
        \ 'Gread', 'Gwrite', 'Gwq',
        \ 'Gdiffsplit', 'Ghdiffsplit', 'Gvdiffsplit',
        \ 'Ggrep', 'Glgrep',
        \ 'GBrowse', 'Gstatus', 'Gblame'
        \ ]
  for cmd in commands
    call s:assert.true(exists(':' . cmd) == 2, cmd . ' command should be registered')
  endfor
endfunction

function! s:suite.verify_command_routing() abort
  " We can inspect the command definition
  redir => l:gedit_info
  silent command Gedit
  redir END
  
  call s:assert.match(l:gedit_info, 'spectregit#edit#Open', 'Gedit should route to spectregit')
  
  redir => l:gstatus_info
  silent command Gstatus
  redir END
  
  call s:assert.match(l:gstatus_info, 'spectregit#status#StatusCommand', 'Gstatus should route to spectregit')
endfunction

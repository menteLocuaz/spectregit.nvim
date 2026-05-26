if exists('g:loaded_spectregit') | finish | endif
let g:loaded_spectregit = 1

if !exists('g:loaded_fugitive') | finish | endif

exe "command! -bar -bang -nargs=? -complete=customlist,spectregit#cd#Complete Gcd exe spectregit#cd#Cd(<q-args>)"
exe "command! -bar -bang -nargs=? -complete=customlist,spectregit#cd#Complete Glcd exe spectregit#cd#Lcd(<q-args>)"

let s:addr_other = has('patch-8.1.560') || has('nvim-0.5.0') ? '-addr=other' : ''
let s:addr_tabs  = has('patch-7.4.542') ? '-addr=tabs' : ''
let s:addr_wins  = has('patch-7.4.542') ? '-addr=windows' : ''

exe 'command! -bar -bang -nargs=*                          -complete=customlist,spectregit#edit#Complete   Ge       exe spectregit#edit#Open("edit<bang>", 0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=*                          -complete=customlist,spectregit#edit#Complete   Gedit    exe spectregit#edit#Open("edit<bang>", 0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=*                          -complete=customlist,spectregit#edit#Complete   Gpedit   exe spectregit#edit#Open("pedit", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -range=-1' s:addr_other '-complete=customlist,spectregit#edit#Complete   Gsplit   exe spectregit#edit#Open((<count> > 0 ? <count> : "").(<count> ? "split" : "edit<bang>"), 0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -range=-1' s:addr_other '-complete=customlist,spectregit#edit#Complete   Gvsplit  exe spectregit#edit#Open((<count> > 0 ? <count> : "").(<count> ? "vsplit" : "edit<bang>"), 0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -range=-1' s:addr_tabs  '-complete=customlist,spectregit#edit#Complete   Gtabedit exe spectregit#edit#Open((<count> >= 0 ? <count> : "")."tabedit", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=*                          -complete=customlist,spectregit#edit#Complete   Gdrop    exe spectregit#edit#DropCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

if exists(':Gr') != 2
  exe 'command! -bar -bang -nargs=* -range=-1                -complete=customlist,spectregit#edit#ReadComplete   Gr     exe spectregit#edit#ReadCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
endif
exe 'command! -bar -bang -nargs=* -range=-1                -complete=customlist,spectregit#edit#ReadComplete   Gread    exe spectregit#edit#ReadCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -nargs=* -complete=customlist,spectregit#edit#Complete Gw     exe spectregit#write#WriteCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,spectregit#edit#Complete Gwrite exe spectregit#write#WriteCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,spectregit#edit#Complete Gwq    exe spectregit#write#WqCommand(   <line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -nargs=* -complete=customlist,spectregit#edit#Complete Gdiffsplit  exe spectregit#diff#Diffsplit(1, <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,spectregit#edit#Complete Ghdiffsplit exe spectregit#diff#Diffsplit(0, <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,spectregit#edit#Complete Gvdiffsplit exe spectregit#diff#Diffsplit(0, <bang>0, "vertical <mods>", <q-args>)'

exe 'command! -bang -nargs=? -range=-1' s:addr_wins '-complete=customlist,spectregit#grep#GrepComplete Ggrep  exe spectregit#grep#GrepCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bang -nargs=? -range=-1' s:addr_wins '-complete=customlist,spectregit#grep#GrepComplete Glgrep exe spectregit#grep#GrepCommand(0, <count> > 0 ? <count> : 0, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -range=-1 -nargs=* -complete=customlist,spectregit#complete#Object GBrowse exe spectregit#browse#BrowseCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -range=-1 -nargs=* -complete=customlist,spectregit#blame#Complete Gblame  exe spectregit#blame#Subcommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", {"subcommand": "blame", "flags": [], "subcommand_args": [<f-args>], "mods": "<mods>"})'

exe 'command! -bar -bang -nargs=* -range=-1 -count=0 -addr=other -complete=customlist,spectregit#complete#Object Gstatus exe spectregit#status#StatusCommand(<line1>, <line2>, <range>, <count>, <bang>0, "<mods>", "<reg>", <q-args>, [<f-args>])'

" Force-load fugitive autoload so its functions exist
call fugitive#GitVersion()

" Replace fugitive's BufReadCmd/BufWriteCmd/FileWriteCmd/SourceCmd autocmds
" with redirects to spectregit. Using autocmd redirection instead of function
" redefinition to avoid E746 (function name != script file name).
silent! autocmd! fugitive BufReadCmd fugitive://*
silent! autocmd! fugitive BufWriteCmd fugitive://*
silent! autocmd! fugitive FileWriteCmd fugitive://*
silent! autocmd! fugitive SourceCmd fugitive://*
augroup spectregit_bufread
  autocmd!
  autocmd BufReadCmd  fugitive://* exe spectregit#autocmd#BufReadCmd()
  autocmd BufWriteCmd fugitive://* exe spectregit#autocmd#BufWriteCmd()
  autocmd FileWriteCmd fugitive://* exe spectregit#autocmd#FileWriteCmd()
  autocmd SourceCmd   fugitive://* exe spectregit#autocmd#SourceCmd()
augroup END

augroup spectregit_status
  autocmd!
  autocmd BufWritePost         * call spectregit#status#DidChange(+expand('<abuf>'), 0)
  autocmd User FileChmodPost,FileUnlinkPost call spectregit#status#DidChange(+expand('<abuf>'), 0)
  autocmd ShellCmdPost,ShellFilterPost * nested call spectregit#status#DidChange(0)
  autocmd QuickFixCmdPost make,lmake,[cl]file,[cl]getfile nested
        \ call spectregit#status#DidChange(fugitive#EfmDir())
  autocmd FocusGained        *
        \ if get(g:, 'fugitive_focus_gained', !has('win32')) |
        \   call spectregit#status#DidChange(0) |
        \ endif
augroup END

augroup spectregit_temp
  autocmd!
  autocmd BufReadPre  * exe spectregit#autocmd#TempReadPre(+expand('<abuf>'))
  autocmd BufReadPost * exe spectregit#autocmd#TempReadPost(+expand('<abuf>'))
  autocmd BufWipeout  * exe spectregit#autocmd#TempDelete(+expand('<abuf>'))
augroup END

augroup spectregit_job
  autocmd!
  autocmd BufDelete * call spectregit#autocmd#RunBufDelete(+expand('<abuf>'))
  autocmd VimLeavePre * call spectregit#core#TempDeleteAll()
augroup END

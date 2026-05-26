if exists('g:loaded_spectregit') | finish | endif
let g:loaded_spectregit = 1

if !exists('g:loaded_fugitive') | finish | endif

" Fugitive script context replicas — needed by body-extracted originals
let s:bad_git_dir = '/$\|^fugitive:'
function! s:Slash(path) abort
  return spectregit#core#Slash(a:path)
endfunction

" Extract function source as Vimscript from :function output.
" Always adds ! to support redefinition via execute().
function! s:ExtractFunctionSource(name) abort
  redir => raw
    silent execute 'function ' . a:name
  redir END
  let lines = split(raw, "\n")
  if empty(lines)
    return ''
  endif
  let first = substitute(lines[0], '^\s*', '', '')
  if first !~# '^function!'
    let first = substitute(first, '^function', 'function!', '')
  endif
  let rest = []
  for i in range(1, len(lines) - 1)
    call add(rest, substitute(lines[i], '^\s*\d\+\s*', '', ''))
  endfor
  return first . "\n" . join(rest, "\n")
endfunction

" Save original function under a permanent s:Orig_<safe> name
" in this script's context. Returns the saved function name (with s: prefix),
" or empty string on failure.
function! s:SaveOriginalFunction(name) abort
  let safe = substitute(a:name, '[^A-Za-z0-9_]', '_', 'g')
  let saved = 's:Orig_' . safe
  if exists('*' . substitute(saved, ':', '#', ''))
    return saved
  endif
  let src = s:ExtractFunctionSource(a:name)
  if empty(src)
    return ''
  endif
  let lines = split(src, "\n")
  let name_esc = escape(a:name, '~.*^$[\&/')
  let lines[0] = substitute(lines[0], '\Cfunction!\s\+' . name_esc . '\ze\s*(',
        \ 'function! ' . saved, '')
  execute join(lines, "\n")
  return saved
endfunction

function! s:CaptureFugitiveOriginals() abort
  if !exists('g:loaded_fugitive') | return | endif

  if exists('*FugitiveGitDir') && !exists('g:Orig_FugitiveGitDir')
    call s:SaveOriginalFunction('FugitiveGitDir')
    let g:Orig_FugitiveGitDir = function('s:Orig_FugitiveGitDir')
  endif
  if exists('*FugitiveStatusline') && !exists('g:Orig_FugitiveStatusline')
    call s:SaveOriginalFunction('FugitiveStatusline')
    let g:Orig_FugitiveStatusline = function('s:Orig_FugitiveStatusline')
  endif
  call s:InstallGuards()
endfunction

function! s:InstallGuards() abort
  function! FugitiveStatusline(...) abort
    if exists('*spectregit#statusline#Get')
      return call('spectregit#statusline#Get', a:000)
    endif
    return call(g:Orig_FugitiveStatusline, a:000)
  endfunction
  function! FugitiveGitDir(...) abort
    if exists('*spectregit#core#GitDirRaw')
      return call('spectregit#core#GitDirRaw', a:000)
    endif
    return call(g:Orig_FugitiveGitDir, a:000)
  endfunction
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
endfunction

augroup spectregit_init
  autocmd!
  autocmd VimEnter * call s:CaptureFugitiveOriginals()
augroup END

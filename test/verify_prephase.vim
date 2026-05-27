" Pre-Phase verification: 0a-0f changes
" Usage: vim -T dumb -N -u NONE -i NONE -S test/verify_prephase.vim
set rtp+=.
runtime! plugin/fugitive.vim
runtime! plugin/spectregit.vim

let g:failures = []

function! s:ok(label, actual, expected) abort
  if a:actual is# a:expected || a:actual ==# a:expected
    echo 'PASS:' a:label
  else
    echo 'FAIL:' a:label '(expected ' . string(a:expected) . ', got ' . string(a:actual) . ')'
    call add(g:failures, a:label)
  endif
endfunction

" 0a: autocmd stubs delegate to fugitive
let s:result = spectregit#autocmd#FileWriteCmd('fugitive:///fake//')
call s:ok('0a: FileWriteCmd delegates', s:result !~# '^$', 1)

let s:result = spectregit#autocmd#BufWriteCmd('fugitive:///fake//')
call s:ok('0a: BufWriteCmd delegates', s:result !~# '^$', 1)

let s:result = spectregit#autocmd#SourceCmd('fugitive:///fake//')
call s:ok('0a: SourceCmd delegates', s:result !~# '^$', 1)

" 0d: shell module loads and works
call spectregit#shell#winshell()
call s:ok('0d: shell#winshell', 1, 1)

let s:escaped = spectregit#shell#shellesc('hello world')
call s:ok('0d: shell#shellesc', s:escaped =~# "'hello world'\\|hello.world\\|\"hello world\"", 1)

" 0e: ClearCaches exists and doesn't error
call spectregit#core#ClearCaches()
call s:ok('0e: core#ClearCaches', 1, 1)

call spectregit#git#ClearCaches()
call s:ok('0e: git#ClearCaches', 1, 1)

call spectregit#path#ClearCaches()
call s:ok('0e: path#ClearCaches', 1, 1)

" 0f: statusline cache clearing works
call spectregit#statusline#ClearCaches()
call s:ok('0f: statusline#ClearCaches', 1, 1)

" Summary
echohl WarningMsg
if len(g:failures)
  echo 'FAILED:' join(g:failures, ', ')
else
  echo 'ALL PRE-PHASE VERIFICATIONS PASSED'
endif
echohl NONE
cq

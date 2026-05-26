" Location:     autoload/spectregit/compat.vim
" Maintainer:   SpectreGit Contributors

" This module serves as a facade for fugitive.vim dependencies.
" Over time, functions here should be refactored to use native git
" or internal spectregit implementations.

" Example utility wrappers:
" function! spectregit#compat#UrlDecode(str) abort
"   return fugitive#UrlDecode(a:str)
" endfunction

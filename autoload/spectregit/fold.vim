if exists('g:autoloaded_spectregit_fold') | finish | endif
let g:autoloaded_spectregit_fold = 1

function! spectregit#fold#Text() abort
  if &foldmethod !=# 'syntax'
    return foldtext()
  endif

  let line_foldstart = getline(v:foldstart)
  if line_foldstart =~# '^diff '
    let [add, remove] = [-1, -1]
    let filename = ''
    for lnum in range(v:foldstart, v:foldend)
      let line = getline(lnum)
      if filename ==# '' && line =~# '^[+-]\{3\} "\=[abciow12]/'
        let filename = fugitive#Unquote(line[4:-1])[2:-1]
      endif
      if line =~# '^+'
        let add += 1
      elseif line =~# '^-'
        let remove += 1
      elseif line =~# '^Binary '
        let binary = 1
      endif
    endfor
    if filename ==# ''
      let filename = fugitive#Unquote(matchstr(line_foldstart, '^diff .\{-\} \zs"\=[abciow12]/\zs.*\ze "\=[abciow12]/'))[2:-1]
    endif
    if filename ==# ''
      let filename = line_foldstart[5:-1]
    endif
    if exists('binary')
      return 'Binary: '.filename
    else
      return '+-' . v:folddashes . ' ' . (add<10&&remove<100?' ':'') . add . '+ ' . (remove<10&&add<100?' ':'') . remove . '- ' . filename
    endif
  elseif line_foldstart =~# '^@@\+ .* @@'
    return '+-' . v:folddashes . ' ' . line_foldstart
  elseif &filetype ==# 'fugitive' && line_foldstart =~# '^[A-Z][a-z].* (\d\+)$'
    let c = +matchstr(line_foldstart, '(\zs\d\+\ze)$')
    return '+-' . v:folddashes . printf('%3d item', c) . (c == 1 ? ':  ' : 's: ') . matchstr(line_foldstart, '.*\ze (\d\+)$')
  elseif &filetype ==# 'gitcommit' && line_foldstart =~# '^# .*:$'
    let lines = getline(v:foldstart, v:foldend)
    call filter(lines, 'v:val =~# "^#\t"')
    call map(lines, "spectregit#core#sub(v:val, '^#\t%(modified: +|renamed: +)=', '')")
    call map(lines, "spectregit#core#sub(v:val, '^([[:alpha:] ]+): +(.*)', '\\2 (\\1)')")
    return line_foldstart.' '.join(lines, ', ')
  endif
  return foldtext()
endfunction

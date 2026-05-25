if exists('g:loaded_spectregit') | finish | endif
let g:loaded_spectregit = 1

if !exists('g:loaded_fugitive') | finish | endif

function! s:CaptureFugitiveOriginals() abort
  if !exists('g:loaded_fugitive') | return | endif
  if exists('*FugitiveGitDir') && !exists('s:orig_FugitiveGitDir')
    let s:orig_FugitiveGitDir = function('FugitiveGitDir')
  endif
  if exists('*FugitiveReal') && !exists('s:orig_FugitiveReal')
    let s:orig_FugitiveReal = function('FugitiveReal')
  endif
  if exists('*FugitiveFind') && !exists('s:orig_FugitiveFind')
    let s:orig_FugitiveFind = function('FugitiveFind')
  endif
  if exists('*FugitiveParse') && !exists('s:orig_FugitiveParse')
    let s:orig_FugitiveParse = function('FugitiveParse')
  endif
  if exists('*FugitiveGitVersion') && !exists('s:orig_FugitiveGitVersion')
    let s:orig_FugitiveGitVersion = function('FugitiveGitVersion')
  endif
  if exists('*FugitiveResult') && !exists('s:orig_FugitiveResult')
    let s:orig_FugitiveResult = function('FugitiveResult')
  endif
  if exists('*FugitiveExecute') && !exists('s:orig_FugitiveExecute')
    let s:orig_FugitiveExecute = function('FugitiveExecute')
  endif
  if exists('*FugitiveShellCommand') && !exists('s:orig_FugitiveShellCommand')
    let s:orig_FugitiveShellCommand = function('FugitiveShellCommand')
  endif
  if exists('*FugitiveConfig') && !exists('s:orig_FugitiveConfig')
    let s:orig_FugitiveConfig = function('FugitiveConfig')
  endif
  if exists('*FugitiveConfigGet') && !exists('s:orig_FugitiveConfigGet')
    let s:orig_FugitiveConfigGet = function('FugitiveConfigGet')
  endif
  if exists('*FugitiveConfigGetAll') && !exists('s:orig_FugitiveConfigGetAll')
    let s:orig_FugitiveConfigGetAll = function('FugitiveConfigGetAll')
  endif
  if exists('*FugitiveConfigGetRegexp') && !exists('s:orig_FugitiveConfigGetRegexp')
    let s:orig_FugitiveConfigGetRegexp = function('FugitiveConfigGetRegexp')
  endif
  if exists('*FugitiveRemoteUrl') && !exists('s:orig_FugitiveRemoteUrl')
    let s:orig_FugitiveRemoteUrl = function('FugitiveRemoteUrl')
  endif
  if exists('*FugitiveRemote') && !exists('s:orig_FugitiveRemote')
    let s:orig_FugitiveRemote = function('FugitiveRemote')
  endif
  if exists('*FugitiveDidChange') && !exists('s:orig_FugitiveDidChange')
    let s:orig_FugitiveDidChange = function('FugitiveDidChange')
  endif
  if exists('*FugitiveHead') && !exists('s:orig_FugitiveHead')
    let s:orig_FugitiveHead = function('FugitiveHead')
  endif
  if exists('*FugitivePath') && !exists('s:orig_FugitivePath')
    let s:orig_FugitivePath = function('FugitivePath')
  endif
  if exists('*FugitiveStatusline') && !exists('s:orig_FugitiveStatusline')
    let s:orig_FugitiveStatusline = function('FugitiveStatusline')
  endif
  if exists('*FugitiveActualDir') && !exists('s:orig_FugitiveActualDir')
    let s:orig_FugitiveActualDir = function('FugitiveActualDir')
  endif
  if exists('*FugitiveCommonDir') && !exists('s:orig_FugitiveCommonDir')
    let s:orig_FugitiveCommonDir = function('FugitiveCommonDir')
  endif
  if exists('*FugitiveWorkTree') && !exists('s:orig_FugitiveWorkTree')
    let s:orig_FugitiveWorkTree = function('FugitiveWorkTree')
  endif
  if exists('*FugitiveIsGitDir') && !exists('s:orig_FugitiveIsGitDir')
    let s:orig_FugitiveIsGitDir = function('FugitiveIsGitDir')
  endif
  if exists('*FugitiveExtractGitDir') && !exists('s:orig_FugitiveExtractGitDir')
    let s:orig_FugitiveExtractGitDir = function('FugitiveExtractGitDir')
  endif
  if exists('*FugitiveDetect') && !exists('s:orig_FugitiveDetect')
    let s:orig_FugitiveDetect = function('FugitiveDetect')
  endif
  if exists('*FugitiveGitPath') && !exists('s:orig_FugitiveGitPath')
    let s:orig_FugitiveGitPath = function('FugitiveGitPath')
  endif
  if exists('*FugitiveVimPath') && !exists('s:orig_FugitiveVimPath')
    let s:orig_FugitiveVimPath = function('FugitiveVimPath')
  endif
  if !exists('*fugitive#Foldtext')
    try
      call fugitive#GitVersion()
    catch
    endtry
  endif
  if exists('*fugitive#Foldtext') && !exists('s:orig_fugitive_Foldtext')
    let s:orig_fugitive_Foldtext = function('fugitive#Foldtext')
  endif
  if exists('*fugitive#statusline') && !exists('s:orig_fugitive_statusline')
    let s:orig_fugitive_statusline = function('fugitive#statusline')
  endif
  if exists('*fugitive#Cwindow') && !exists('s:orig_fugitive_Cwindow')
    let s:orig_fugitive_Cwindow = function('fugitive#Cwindow')
  endif
  if exists('*fugitive#repo') && !exists('s:orig_fugitive_repo')
    let s:orig_fugitive_repo = function('fugitive#repo')
  endif
  if exists('*fugitive#CompletePath') && !exists('s:orig_fugitive_CompletePath')
    let s:orig_fugitive_CompletePath = function('fugitive#CompletePath')
  endif
  if exists('*fugitive#PathComplete') && !exists('s:orig_fugitive_PathComplete')
    let s:orig_fugitive_PathComplete = function('fugitive#PathComplete')
  endif
  if exists('*fugitive#CompleteObject') && !exists('s:orig_fugitive_CompleteObject')
    let s:orig_fugitive_CompleteObject = function('fugitive#CompleteObject')
  endif
  if exists('*fugitive#GitVersion') && !exists('s:orig_fugitive_GitVersion')
    let s:orig_fugitive_GitVersion = function('fugitive#GitVersion')
  endif
  if exists('*fugitive#Head') && !exists('s:orig_fugitive_Head')
    let s:orig_fugitive_Head = function('fugitive#Head')
  endif
  if exists('*fugitive#RevParse') && !exists('s:orig_fugitive_RevParse')
    let s:orig_fugitive_RevParse = function('fugitive#RevParse')
  endif
  if exists('*fugitive#Autowrite') && !exists('s:orig_fugitive_Autowrite')
    let s:orig_fugitive_Autowrite = function('fugitive#Autowrite')
  endif
  if exists('*fugitive#Wait') && !exists('s:orig_fugitive_Wait')
    let s:orig_fugitive_Wait = function('fugitive#Wait')
  endif
  if exists('*fugitive#Parse') && !exists('s:orig_fugitive_Parse')
    let s:orig_fugitive_Parse = function('fugitive#Parse')
  endif
  if exists('*fugitive#Real') && !exists('s:orig_fugitive_Real')
    let s:orig_fugitive_Real = function('fugitive#Real')
  endif
  if exists('*fugitive#Path') && !exists('s:orig_fugitive_Path')
    let s:orig_fugitive_Path = function('fugitive#Path')
  endif
  if exists('*fugitive#Config') && !exists('s:orig_fugitive_Config')
    let s:orig_fugitive_Config = function('fugitive#Config')
  endif
  if exists('*fugitive#ConfigGetAll') && !exists('s:orig_fugitive_ConfigGetAll')
    let s:orig_fugitive_ConfigGetAll = function('fugitive#ConfigGetAll')
  endif
  if exists('*fugitive#ConfigGetRegexp') && !exists('s:orig_fugitive_ConfigGetRegexp')
    let s:orig_fugitive_ConfigGetRegexp = function('fugitive#ConfigGetRegexp')
  endif
  if exists('*fugitive#Remote') && !exists('s:orig_fugitive_Remote')
    let s:orig_fugitive_Remote = function('fugitive#Remote')
  endif
  if exists('*fugitive#RemoteUrl') && !exists('s:orig_fugitive_RemoteUrl')
    let s:orig_fugitive_RemoteUrl = function('fugitive#RemoteUrl')
  endif
  if exists('*fugitive#SshConfig') && !exists('s:orig_fugitive_SshConfig')
    let s:orig_fugitive_SshConfig = function('fugitive#SshConfig')
  endif
  if exists('*fugitive#ExpireConfig') && !exists('s:orig_fugitive_ExpireConfig')
    let s:orig_fugitive_ExpireConfig = function('fugitive#ExpireConfig')
  endif
  call s:InstallGuards()
endfunction

function! s:InstallGuards() abort
  function! FugitiveStatusline(...) abort
    if exists('*spectregit#statusline#Get')
      return call('spectregit#statusline#Get', a:000)
    endif
    return call(s:orig_FugitiveStatusline, a:000)
  endfunction
  if exists('*fugitive#Foldtext')
    function! fugitive#Foldtext() abort
      if exists('*spectregit#fold#Text')
        return spectregit#fold#Text()
      endif
      return s:orig_fugitive_Foldtext()
    endfunction
  endif
  if exists('*fugitive#statusline')
    function! fugitive#statusline() abort
      if exists('*spectregit#statusline#Get')
        return spectregit#statusline#Get()
      endif
      return s:orig_fugitive_statusline()
    endfunction
  endif
  if exists('*fugitive#Cwindow')
    function! fugitive#Cwindow() abort
      if exists('*spectregit#quickfix#Cwindow')
        return spectregit#quickfix#Cwindow()
      endif
      return s:orig_fugitive_Cwindow()
    endfunction
  endif
  if exists('*fugitive#GitVersion')
    function! fugitive#GitVersion(...) abort
      if exists('*spectregit#git#GitVersion')
        return call('spectregit#git#GitVersion', a:000)
      endif
      return call(s:orig_fugitive_GitVersion, a:000)
    endfunction
  endif
  if exists('*fugitive#Head')
    function! fugitive#Head(...) abort
      if exists('*spectregit#git#Head')
        return call('spectregit#git#Head', a:000)
      endif
      return call(s:orig_fugitive_Head, a:000)
    endfunction
  endif
  if exists('*fugitive#RevParse')
    function! fugitive#RevParse(rev, ...) abort
      if exists('*spectregit#git#RevParse')
        return call('spectregit#git#RevParse', [a:rev] + a:000)
      endif
      return call(s:orig_fugitive_RevParse, [a:rev] + a:000)
    endfunction
  endif
  if exists('*fugitive#Autowrite')
    function! fugitive#Autowrite() abort
      if exists('*spectregit#git#Autowrite')
        return spectregit#git#Autowrite()
      endif
      return s:orig_fugitive_Autowrite()
    endfunction
  endif
  if exists('*fugitive#Wait')
    function! fugitive#Wait(job_or_jobs, ...) abort
      if exists('*spectregit#git#Wait')
        return call('spectregit#git#Wait', [a:job_or_jobs] + a:000)
      endif
      return call(s:orig_fugitive_Wait, [a:job_or_jobs] + a:000)
    endfunction
  endif
  if exists('*fugitive#Parse')
    function! fugitive#Parse(...) abort
      if exists('*spectregit#path#Parse')
        return call('spectregit#path#Parse', a:000)
      endif
      return call(s:orig_fugitive_Parse, a:000)
    endfunction
  endif
  if exists('*fugitive#Real')
    function! fugitive#Real(...) abort
      if exists('*spectregit#path#Real')
        return call('spectregit#path#Real', a:000)
      endif
      return call(s:orig_fugitive_Real, a:000)
    endfunction
  endif
  if exists('*fugitive#Path')
    function! fugitive#Path(...) abort
      if exists('*spectregit#path#Path')
        return call('spectregit#path#Path', a:000)
      endif
      return call(s:orig_fugitive_Path, a:000)
    endfunction
  endif
  if exists('*fugitive#repo')
    function! fugitive#repo(...) abort
      if exists('*spectregit#repo#New')
        return call('spectregit#repo#New', a:000)
      endif
      return call(s:orig_fugitive_repo, a:000)
    endfunction
  endif
  if exists('*fugitive#CompletePath')
    function! fugitive#CompletePath(base, ...) abort
      if exists('*spectregit#complete#CompletePath')
        return call('spectregit#complete#CompletePath', [a:base] + a:000)
      endif
      return call(s:orig_fugitive_CompletePath, [a:base] + a:000)
    endfunction
  endif
  if exists('*fugitive#PathComplete')
    function! fugitive#PathComplete(...) abort
      if exists('*spectregit#complete#PathComplete')
        return call('spectregit#complete#PathComplete', a:000)
      endif
      return call(s:orig_fugitive_PathComplete, a:000)
    endfunction
  endif
  if exists('*fugitive#CompleteObject')
    function! fugitive#CompleteObject(base, ...) abort
      if exists('*spectregit#complete#Object')
        return call('spectregit#complete#Object', [a:base] + a:000)
      endif
      return call(s:orig_fugitive_CompleteObject, [a:base] + a:000)
    endfunction
  endif
  if exists('*fugitive#Config')
    function! fugitive#Config(...) abort
      if exists('*spectregit#config#Config')
        return call('spectregit#config#Config', a:000)
      endif
      return call(s:orig_fugitive_Config, a:000)
    endfunction
  endif
  if exists('*fugitive#ConfigGetAll')
    function! fugitive#ConfigGetAll(name, ...) abort
      if exists('*spectregit#config#ConfigGetAll')
        return call('spectregit#config#ConfigGetAll', [a:name] + a:000)
      endif
      return call(s:orig_fugitive_ConfigGetAll, [a:name] + a:000)
    endfunction
  endif
  if exists('*fugitive#ConfigGetRegexp')
    function! fugitive#ConfigGetRegexp(pattern, ...) abort
      if exists('*spectregit#config#ConfigGetRegexp')
        return call('spectregit#config#ConfigGetRegexp', [a:pattern] + a:000)
      endif
      return call(s:orig_fugitive_ConfigGetRegexp, [a:pattern] + a:000)
    endfunction
  endif
  if exists('*fugitive#Remote')
    function! fugitive#Remote(...) abort
      if exists('*spectregit#config#Remote')
        return call('spectregit#config#Remote', a:000)
      endif
      return call(s:orig_fugitive_Remote, a:000)
    endfunction
  endif
  if exists('*fugitive#RemoteUrl')
    function! fugitive#RemoteUrl(...) abort
      if exists('*spectregit#config#RemoteUrl')
        return call('spectregit#config#RemoteUrl', a:000)
      endif
      return call(s:orig_fugitive_RemoteUrl, a:000)
    endfunction
  endif
  if exists('*fugitive#SshConfig')
    function! fugitive#SshConfig(host, ...) abort
      if exists('*spectregit#config#SshConfig')
        return call('spectregit#config#SshConfig', [a:host] + a:000)
      endif
      return call(s:orig_fugitive_SshConfig, [a:host] + a:000)
    endfunction
  endif
  if exists('*fugitive#ExpireConfig')
    function! fugitive#ExpireConfig(...) abort
      if exists('*spectregit#config#ExpireConfig')
        return call('spectregit#config#ExpireConfig', a:000)
      endif
      return call(s:orig_fugitive_ExpireConfig, a:000)
    endfunction
  endif
  exe "command! -bar -bang -nargs=? -complete=customlist,spectregit#cd#Complete Gcd exe spectregit#cd#Cd(<q-args>)"
  exe "command! -bar -bang -nargs=? -complete=customlist,spectregit#cd#Complete Glcd exe spectregit#cd#Lcd(<q-args>)"
endfunction

augroup spectregit_init
  autocmd!
  autocmd VimEnter * call s:CaptureFugitiveOriginals()
augroup END

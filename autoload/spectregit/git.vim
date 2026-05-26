if exists('g:autoloaded_spectregit_git') | finish | endif
let g:autoloaded_spectregit_git = 1

let s:run_jobs = (exists('*ch_close_in') || exists('*jobstart')) && exists('*bufwinid')
let s:git_versions = {}
let s:temp_scripts = {}

function! spectregit#git#GitVersion(...) abort
  let git = s:GitShellCmd()
  if !has_key(s:git_versions, git)
    let s:git_versions[git] = matchstr(get(fugitive#Execute(['--version']).stdout, 0, ''), '\d[^[:space:]]\+')
  endif
  if !a:0
    return s:git_versions[git]
  endif
  let components = split(s:git_versions[git], '\D\+')
  if empty(components)
    return -1
  endif
  for i in range(len(a:000))
    if a:000[i] > +get(components, i)
      return 0
    elseif a:000[i] < +get(components, i)
      return 1
    endif
  endfor
  return a:000[i] ==# get(components, i)
endfunction

function! s:GitShellCmd() abort
  if !exists('g:fugitive_git_executable')
    return 'git'
  elseif type(g:fugitive_git_executable) == type([])
    return join(map(copy(g:fugitive_git_executable), 'shellescape(v:val)'))
  else
    return g:fugitive_git_executable
  endif
endfunction

function! s:TempScript(...) abort
  let body = join(a:000, "\n")
  if !has_key(s:temp_scripts, body)
    let s:temp_scripts[body] = tempname() . '.sh'
  endif
  let temp = s:temp_scripts[body]
  if !filereadable(temp)
    call writefile(['#!/bin/sh'] + a:000, temp)
  endif
  let temp = FugitiveGitPath(temp)
  if temp =~# '\s'
    let temp = '"' . temp . '"'
  endif
  return temp
endfunction

function! spectregit#git#Autowrite() abort
  if &autowrite || &autowriteall
    try
      if &confirm
        let reconfirm = 1
        setglobal noconfirm
      endif
      silent! wall
    finally
      if exists('reconfirm')
        setglobal confirm
      endif
    endtry
  endif
  return ''
endfunction

function! spectregit#git#Wait(job_or_jobs, ...) abort
  let original = type(a:job_or_jobs) == type([]) ? copy(a:job_or_jobs) : [a:job_or_jobs]
  let jobs = map(copy(original), 'type(v:val) ==# type({}) ? get(v:val, "job", "") : v:val')
  call filter(jobs, 'type(v:val) !=# type("")')
  let timeout_ms = a:0 ? a:1 : -1
  if exists('*jobwait')
    call map(copy(jobs), 'chanclose(v:val, "stdin")')
    call jobwait(jobs, timeout_ms)
    let jobs = map(copy(original), 'type(v:val) ==# type({}) ? get(v:val, "job", "") : v:val')
    call filter(jobs, 'type(v:val) !=# type("")')
    if len(jobs)
      sleep 1m
    endif
  else
    for job in jobs
      if ch_status(job) ==# 'open'
        call ch_close_in(job)
      endif
    endfor
    let i = 0
    for job in jobs
      while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
        if i == timeout_ms
          break
        endif
        let i += 1
        sleep 1m
      endwhile
    endfor
  endif
  return a:job_or_jobs
endfunction

let s:head_cache = {}
function! spectregit#git#Head(...) abort
  let dir = a:0 > 1 ? a:2 : spectregit#core#Dir()
  if empty(dir)
    return ''
  endif
  let file = FugitiveActualDir(dir) . '/HEAD'
  let ftime = getftime(file)
  if ftime == -1
    return ''
  elseif ftime != get(s:head_cache, file, [-1])[0]
    let s:head_cache[file] = [ftime, readfile(file)[0]]
  endif
  let head = s:head_cache[file][1]
  let len = a:0 ? a:1 : 0
  if head =~# '^ref: '
    if len < 0
      return strpart(head, 5)
    else
      return substitute(head, '\C^ref: \%(refs/\%(heads/\|remotes/\|tags/\)\=\)\=', '', '')
    endif
  elseif head =~# '^\x\{40,\}$'
    return len < 0 ? head : strpart(head, 0, len)
  else
    return ''
  endif
endfunction

let s:merge_heads = ['MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD']
function! spectregit#git#CompleteHeads(dir) abort
  if empty(a:dir)
    return []
  endif
  let dir = FugitiveFind('.git/', a:dir)
  return sort(filter(['HEAD', 'FETCH_HEAD', 'ORIG_HEAD'] + s:merge_heads, 'filereadable(dir . v:val)')) +
        \ sort(spectregit#core#LinesError([a:dir, 'rev-parse', '--symbolic', '--branches', '--tags', '--remotes'])[0])
endfunction

function! spectregit#git#RevParse(rev, ...) abort
  let hash = spectregit#core#ChompDefault('', [a:0 ? a:1 : spectregit#core#Dir(), 'rev-parse', '--verify', a:rev, '--'])
  if hash =~# '^\x\{40,\}$'
    return hash
  endif
  throw 'fugitive: failed to parse revision ' . a:rev
endfunction

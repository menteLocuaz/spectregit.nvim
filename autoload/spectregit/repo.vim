if exists('g:autoloaded_spectregit_repo') | finish | endif
let g:autoloaded_spectregit_repo = 1

let s:prototype = {}

function! s:add_methods(namespace, method_names) abort
  for name in a:method_names
    let s:prototype[name] = function('s:' . a:namespace . '_' . name)
  endfor
endfunction

function! spectregit#repo#Get(...) abort
  let dir = a:0 ? spectregit#core#Dir(a:1) : (len(spectregit#core#Dir()) ? spectregit#core#Dir() : FugitiveExtractGitDir(expand('%:p')))
  if dir !=# ''
    return extend({'git_dir': dir, 'fugitive_dir': dir}, s:prototype, 'keep')
  endif
  throw 'fugitive: not a Git repository'
endfunction

function! s:repo_dir(...) dict abort
  if !a:0
    return self.git_dir
  endif
  throw 'fugitive: spectregit#repo#Get().dir("...") has been replaced by spectregit#path#Find(".git/...")'
endfunction

function! s:repo_tree(...) dict abort
  let tree = spectregit#core#Tree(self.git_dir)
  if empty(tree)
    throw 'fugitive: no work tree'
  elseif !a:0
    return tree
  endif
  throw 'fugitive: spectregit#repo#Get().tree("...") has been replaced by spectregit#path#Find(":(top)...")'
endfunction

function! s:repo_bare() dict abort
  throw 'fugitive: fugitive#repo().bare() has been replaced by !empty(spectregit#core#Tree())'
endfunction

function! s:repo_find(object) dict abort
  return spectregit#path#Find(a:object, self.git_dir)
endfunction

function! s:repo_translate(rev) dict abort
  throw 'fugitive: fugitive#repo().translate(...) has been replaced by spectregit#path#Find(...)'
endfunction

function! s:repo_head(...) dict abort
  return spectregit#git#Head(a:0 ? a:1 : 0, self.git_dir)
endfunction

call s:add_methods('repo', ['dir', 'tree', 'bare', 'find', 'translate', 'head'])

function! s:repo_git_command(...) dict abort
  return spectregit#git#ShellCommand(a:000, self.git_dir)
endfunction

function! s:repo_git_chomp(...) dict abort
  silent return substitute(system(spectregit#git#ShellCommand(a:000, self.git_dir)), '\n$', '', '')
endfunction

function! s:repo_git_chomp_in_tree(...) dict abort
  return call(self.git_chomp, a:000, self)
endfunction

function! s:repo_rev_parse(rev) dict abort
  throw 'fugitive: spectregit#repo#Get().rev_parse(...) has been replaced by spectregit#git#Execute("rev-parse", "--verify", ...).stdout'
endfunction

call s:add_methods('repo', ['git_command', 'git_chomp', 'git_chomp_in_tree', 'rev_parse'])

function! s:repo_config(name) dict abort
  return spectregit#config#Config(a:name, self.git_dir)
endfunction

call s:add_methods('repo', ['config'])

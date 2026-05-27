if exists('g:autoloaded_spectregit_config') | finish | endif
let g:autoloaded_spectregit_config = 1

let s:save_cpo = &cpo
set cpo&vim

let s:config_prototype = {}
let s:config = {}

function! s:ConfigTimestamps(dir, dict) abort
  let files = ['/etc/gitconfig', '~/.gitconfig',
        \ len($XDG_CONFIG_HOME) ? $XDG_CONFIG_HOME . '/git/config' : '~/.config/git/config']
  if len(a:dir)
    call add(files, spectregit#path#Find('.git/config', a:dir))
  endif
  call extend(files, get(a:dict, 'include.path', []))
  return join(map(files, 'getftime(expand(v:val))'), ',')
endfunction

function! s:ConfigCallback(r, into) abort
  let dict = a:into[1]
  if has_key(dict, 'job')
    call remove(dict, 'job')
  endif
  let lines = a:r.exit_status ? [] : split(tr(join(a:r.stdout, "\1"), "\1\n", "\n\1"), "\1", 1)[0:-2]
  for line in lines
    let key = matchstr(line, "^[^\n]*")
    if !has_key(dict, key)
      let dict[key] = []
    endif
    if len(key) ==# len(line)
      call add(dict[key], 1)
    else
      call add(dict[key], strpart(line, len(key) + 1))
    endif
  endfor
  let callbacks = remove(dict, 'callbacks')
  lockvar! dict
  let a:into[0] = s:ConfigTimestamps(dict.git_dir, dict)
  for callback in callbacks
    call call(callback[0], [dict] + callback[1:-1])
  endfor
endfunction

function! spectregit#config#ExpireConfig(...) abort
  if !a:0 || a:1 is# 0
    let s:config = {}
  else
    let key = a:1 is# '' ? '_' : spectregit#core#Dir(a:0 ? a:1 : -1)
    if len(key) && has_key(s:config, key)
      call remove(s:config, key)
    endif
  endif
endfunction

function! spectregit#config#Config(...) abort
  let name = ''
  let default = get(a:, 3, '')
  if a:0 && type(a:1) == type(function('tr'))
    let dir = spectregit#core#Dir()
    let callback = a:000
  elseif a:0 > 1 && type(a:2) == type(function('tr'))
    if type(a:1) == type({}) && has_key(a:1, 'GetAll')
      if has_key(a:1, 'callbacks')
        call add(a:1.callbacks, a:000[1:-1])
      else
        call call(a:2, [a:1] + a:000[2:-1])
      endif
      return a:1
    else
      let dir = spectregit#core#Dir(a:1)
      let callback = a:000[1:-1]
    endif
  elseif a:0 >= 2 && type(a:2) == type({}) && has_key(a:2, 'GetAll')
    return get(spectregit#config#ConfigGetAll(a:1, a:2), -1, default)
  elseif a:0 >= 2
    let dir = spectregit#core#Dir(a:2)
    let name = a:1
  elseif a:0 == 1 && type(a:1) == type({}) && has_key(a:1, 'GetAll')
    return a:1
  elseif a:0 == 1 && type(a:1) == type('') && a:1 =~# '^[[:alnum:]-]\+\.'
    let dir = spectregit#core#Dir()
    let name = a:1
  elseif a:0 == 1
    let dir = spectregit#core#Dir(a:1)
  else
    let dir = spectregit#core#Dir()
  endif
  let name = substitute(name, '^[^.]\+\|[^.]\+$', '\L&', 'g')
  let git_dir = spectregit#core#Dir(dir)
  let dir_key = len(git_dir) ? git_dir : '_'
  let [ts, dict] = get(s:config, dir_key, ['new', {}])
  if !has_key(dict, 'job') && ts !=# s:ConfigTimestamps(git_dir, dict)
    let dict = copy(s:config_prototype)
    let dict.git_dir = git_dir
    let into = ['running', dict]
    let dict.callbacks = []
    let exec = spectregit#git#Execute([dir, 'config', '--list', '-z', '--'], function('s:ConfigCallback'), into)
    if has_key(exec, 'job')
      let dict.job = exec.job
    endif
    let s:config[dir_key] = into
  endif
  if !exists('l:callback')
    call spectregit#git#Wait(dict)
  elseif has_key(dict, 'callbacks')
    call add(dict.callbacks, callback)
  else
    call call(callback[0], [dict] + callback[1:-1])
  endif
  return len(name) ? get(spectregit#config#ConfigGetAll(name, dict), 0, default) : dict
endfunction

function! spectregit#config#ConfigGetAll(name, ...) abort
  if a:0 && (type(a:name) !=# type('') || a:name !~# '^[[:alnum:]-]\+\.' && type(a:1) ==# type('') && a:1 =~# '^[[:alnum:]-]\+\.')
    let config = spectregit#config#Config(a:name)
    let name = a:1
  else
    let config = spectregit#config#Config(a:0 ? a:1 : spectregit#core#Dir())
    let name = a:name
  endif
  let name = substitute(name, '^[^.]\+\|[^.]\+$', '\L&', 'g')
  call spectregit#git#Wait(config)
  return name =~# '\.' ? copy(get(config, name, [])) : []
endfunction

function! spectregit#config#ConfigGetRegexp(pattern, ...) abort
  if type(a:pattern) !=# type('')
    let config = spectregit#config#Config(a:name)
    let pattern = a:0 ? a:1 : '.*'
  else
    let config = spectregit#config#Config(a:0 ? a:1 : spectregit#core#Dir())
    let pattern = a:pattern
  endif
  call spectregit#git#Wait(config)
  let filtered = map(filter(copy(config), 'v:key =~# "\\." && v:key =~# pattern'), 'copy(v:val)')
  if pattern !~# '\\\@<!\%(\\\\\)*\\z[se]'
    return filtered
  endif
  let transformed = {}
  for [k, v] in items(filtered)
    let k = matchstr(k, pattern)
    if len(k)
      let transformed[k] = v
    endif
  endfor
  return transformed
endfunction

function! s:config_GetAll(name) dict abort
  let name = substitute(a:name, '^[^.]\+\|[^.]\+$', '\L&', 'g')
  call spectregit#git#Wait(self)
  return name =~# '\.' ? copy(get(self, name, [])) : []
endfunction

function! s:config_Get(name, ...) dict abort
  return get(self.GetAll(a:name), -1, a:0 ? a:1 : '')
endfunction

function! s:config_GetRegexp(pattern) dict abort
  return spectregit#config#ConfigGetRegexp(self, a:pattern)
endfunction

function! s:add_methods(namespace, method_names) abort
  for name in a:method_names
    let s:{a:namespace}_prototype[name] = function('s:' . a:namespace . '_' . name)
  endfor
endfunction

call s:add_methods('config', ['GetAll', 'Get', 'GetRegexp'])

function! spectregit#config#RemoteUrl(...) abort
  let remote = spectregit#config#Remote(a:000)
  return get(remote, 'url', '')
endfunction

function! s:RemoteDefault(dir) abort
  let head = spectregit#git#Head(0, a:dir)
  let remote = len(head) ? spectregit#config#Config('branch.' . head . '.remote', a:dir) : ''
  let i = 10
  while remote ==# '.' && i > 0
    let head = matchstr(spectregit#config#Config('branch.' . head . '.merge', a:dir), 'refs/heads/\zs.*')
    let remote = len(head) ? spectregit#config#Config('branch.' . head . '.remote', a:dir) : ''
    let i -= 1
  endwhile
  return remote =~# '^\.\=$' ? 'origin' : remote
endfunction

function! s:UrlParse(url) abort
  let scp_authority = matchstr(a:url, '^[^:/]\+\ze:\%(//\)\@!')
  if len(scp_authority) && !(has('win32') && scp_authority =~# '^\a:[\/]')
    let url = {'scheme': 'ssh', 'authority': spectregit#core#UrlEncode(scp_authority), 'hash': '',
          \ 'path': spectregit#core#UrlEncode(strpart(a:url, len(scp_authority) + 1))}
  elseif empty(a:url)
    let url = {'scheme': '', 'authority': '', 'path': '', 'hash': ''}
  else
    let match = matchlist(a:url, '^\([[:alnum:].+-]\+\)://\([^/]*\)\(/[^#]*\)\=\(#.*\)\=$')
    if empty(match)
      let url = {'scheme': 'file', 'authority': '', 'hash': '',
            \ 'path': spectregit#core#UrlEncode(a:url)}
    else
      let url = {'scheme': match[1], 'authority': match[2], 'hash': match[4]}
      let url.path = empty(match[3]) ? '/' : match[3]
    endif
  endif
  return url
endfunction

function! s:UrlPopulate(string, into) abort
  let url = a:into
  let url.protocol = substitute(url.scheme, '.\zs$', ':', '')
  let url.user = spectregit#core#UrlDecode(matchstr(url.authority, '.\{-\}\ze@', '', ''))
  let url.host = substitute(url.authority, '.\{-\}@', '', '')
  let url.hostname = substitute(url.host, ':\d\+$', '', '')
  let url.port = matchstr(url.host, ':\zs\d\+$', '', '')
  let url.origin = substitute(url.scheme, '.\zs$', '://', '') . url.host
  let url.search = matchstr(url.path, '?.*')
  let url.pathname = '/' . matchstr(url.path, '^/\=\zs[^?]*')
  if (url.scheme ==# 'ssh' || url.scheme ==# 'git') && url.path[0:1] ==# '/~'
    let url.path = strpart(url.path, 1)
  endif
  if url.path =~# '^/'
    let url.href = url.scheme . '://' . url.authority . url.path . url.hash
  elseif url.path =~# '^\~'
    let url.href = url.scheme . '://' . url.authority . '/' . url.path . url.hash
  elseif url.scheme ==# 'ssh' && url.authority !~# ':'
    let url.href = url.authority . ':' . url.path . url.hash
  else
    let url.href = a:string
  endif
  let url.path = spectregit#core#UrlDecode(matchstr(url.path, '^[^?]*'))
  let url.url = matchstr(url.href, '^[^#]*')
endfunction

function! s:ConfigLengthSort(i1, i2) abort
  return len(a:i2[0]) - len(a:i1[0])
endfunction

let s:remote_headers = {}

function! spectregit#config#RemoteHttpHeaders(remote) abort
  let remote = type(a:remote) ==# type({}) ? get(a:remote, 'remote', '') : a:remote
  if type(remote) !=# type('') || remote !~# '^https\=://.' || !executable('curl')
    return {}
  endif
  let remote = substitute(remote, '#.*', '', '')
  if !has_key(s:remote_headers, remote)
    let url = remote . '/info/refs?service=git-upload-pack'
    let exec = spectregit#git#Execute(
          \ ['curl', '--disable', '--silent', '--max-time', '5', '-X', 'GET', '-I',
          \ url], {}, [], [function('s:CurlResponse')], {})
    call spectregit#git#Wait(exec)
    let s:remote_headers[remote] = exec.headers
  endif
  return s:remote_headers[remote]
endfunction

function! s:CurlResponse(result) abort
  let a:result.headers = {}
  for line in a:result.exit_status ? [] : remove(a:result, 'stdout')
    let header = matchlist(line, '^\([[:alnum:]-]\+\):\s\(.\{-\}\)'. "\r\\=$")
    if len(header)
      let k = tolower(header[1])
      if has_key(a:result.headers, k)
        let a:result.headers[k] .= ', ' . header[2]
      else
        let a:result.headers[k] = header[2]
      endif
    elseif empty(line)
      break
    endif
  endfor
endfunction

function! spectregit#config#SshHostAlias(authority) abort
  let [_, user, host, port; __] = matchlist(a:authority, '^\%(\([^/@]\+\)@\)\=\(.\{-\}\)\%(:\(\d\+\)\)\=$')
  let c = spectregit#config#SshConfig(host, ['user', 'hostname', 'port'])
  if empty(user)
    let user = get(c, 'user', '')
  endif
  if empty(port)
    let port = get(c, 'port', '')
  endif
  return (len(user) ? user . '@' : '') . get(c, 'hostname', host) . (port =~# '^\%(22\)\=$' ? '' : ':' . port)
endfunction

function! spectregit#config#RemoteResolve(url, flags) abort
  let remote = s:UrlParse(a:url)
  if remote.scheme =~# '^https\=$' && index(a:flags, ':nohttp') < 0
    let headers = spectregit#config#RemoteHttpHeaders(a:url)
    let loc = matchstr(get(headers, 'location', ''), '^https\=://.\{-\}\ze/info/refs?')
    if len(loc)
      let remote = s:UrlParse(loc)
    else
      let remote.headers = headers
    endif
  elseif remote.scheme ==# 'ssh'
    let remote.authority = spectregit#config#SshHostAlias(remote.authority)
  endif
  return remote
endfunction

function! s:RemoteCallback(config, into, flags, cb) abort
  if a:into.remote_name =~# '^\.\=$'
    let a:into.remote_name = s:RemoteDefault(a:config)
  endif
  let url = a:into.remote_name
  if url ==# '.git'
    let url = spectregit#core#Dir(a:config)
  elseif url !~# ':\|^/\|^\a:[\/]\|^\.\.\=/'
    let url = spectregit#config#Config('remote.' . url . '.url', a:config)
  endif
  let instead_of = []
  for [k, vs] in items(spectregit#config#ConfigGetRegexp('^url\.\zs.\{-\}\ze\.insteadof$', a:config))
    for v in vs
      call add(instead_of, [v, k])
    endfor
  endfor
  call sort(instead_of, 's:ConfigLengthSort')
  for [orig, replacement] in instead_of
    if strpart(url, 0, len(orig)) ==# orig
      let url = replacement . strpart(url, len(orig))
      break
    endif
  endfor
  if index(a:flags, ':noresolve') < 0
    call extend(a:into, spectregit#config#RemoteResolve(url, a:flags))
  else
    call extend(a:into, s:UrlParse(url))
  endif
  call s:UrlPopulate(url, a:into)
  if len(a:cb)
    call call(a:cb[0], [a:into] + a:cb[1:-1])
  endif
endfunction

function! spectregit#config#Remote(...) abort
  let [dir_or_config, remote, flags, cb] = s:RemoteParseArgs(a:000)
  return s:Remote(dir_or_config, remote, flags, cb)
endfunction

function! s:RemoteParseArgs(args) abort
  let args = []
  let flags = []
  let cb = copy(a:args)
  while len(cb)
    if type(cb[0]) == type(function('tr'))
      break
    elseif len(args) > 1 || type(cb[0]) == type('') && cb[0] =~# '^:'
      call add(flags, remove(cb, 0))
    else
      call add(args, remove(cb, 0))
    endif
  endwhile
  let remote = ''
  if empty(args)
    let dir_or_config = spectregit#core#Dir()
  elseif len(args) == 1 && type(args[0]) == type('') && args[0] !~# '^/\|^\a:[\\/]'
    let dir_or_config = spectregit#core#Dir()
    let remote = args[0]
  elseif len(args) == 1
    let dir_or_config = args[0]
    if type(args[0]) == type({}) && has_key(args[0], 'remote_name')
      let remote = args[0].remote_name
    endif
  elseif type(args[1]) !=# type('') || args[1] =~# '^/\|^\a:[\\/]'
    let dir_or_config = args[1]
    let remote = args[0]
  else
    let dir_or_config = args[0]
    let remote = args[1]
  endif
  return [dir_or_config, remote, flags, cb]
endfunction

function! s:Remote(dir, remote, flags, cb) abort
  let into = {'remote_name': a:remote, 'git_dir': spectregit#core#Dir(a:dir)}
  let config = spectregit#config#Config(a:dir, function('s:RemoteCallback'), into, a:flags, a:cb)
  if len(a:cb)
    return config
  else
    call spectregit#git#Wait(config)
    return into
  endif
endfunction

function! spectregit#config#SshConfig(host, ...) abort
  if !exists('s:ssh_config')
    let s:ssh_config = {}
    for file in [expand("~/.ssh/config"), "/etc/ssh/ssh_config"]
      call s:SshParseConfig(s:ssh_config, substitute(file, '\w*$', '', ''), file)
    endfor
  endif
  let host_config = {}
  for key in a:0 ? a:1 : keys(s:ssh_config)
    for [host_pattern, value] in get(s:ssh_config, key, [])
      if a:host =~# host_pattern
        let host_config[key] = value
        break
      endif
    endfor
  endfor
  return host_config
endfunction

function! s:SshParseConfig(into, root, file) abort
  try
    let lines = readfile(a:file)
  catch
    return a:into
  endtry
  let host = '^\%(.*\)$'
  while !empty(lines)
    let line = remove(lines, 0)
    let key = tolower(matchstr(line, '^\s*\zs\w\+\ze\s'))
    let value = matchstr(line, '^\s*\w\+\s\+\zs.*\S')
    if key ==# 'match'
      let host = value ==# 'all' ? '^\%(.*\)$' : ''
    elseif key ==# 'host'
      let host = s:SshParseHost(value)
    elseif key ==# 'include'
      for glob in split(value)
        if glob !~# '^[~/]'
          let glob = a:root . glob
        endif
        for included in reverse(split(glob(glob), "\n"))
          try
            call extend(lines, readfile(included), 'keep')
          catch
          endtry
        endfor
      endfor
    elseif len(key) && len(host)
      call extend(a:into, {key : []}, 'keep')
      call add(a:into[key], [host, value])
    endif
  endwhile
  return a:into
endfunction

function! s:SshParseHost(value) abort
  let patterns = []
  let negates = []
  for host in split(a:value, '\s\+')
    let pattern = substitute(host, '[\\^$.*~?]', '\=submatch(0) == "*" ? ".*" : submatch(0) == "?" ? "." : "\\" . submatch(0)', 'g')
    if pattern[0] ==# '!'
      call add(negates, '\&\%(^' . pattern[1 : -1] . '$\)\@!')
    else
      call add(patterns, pattern)
    endif
  endfor
  return '^\%(' . join(patterns, '\|') . '\)$' . join(negates, '')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

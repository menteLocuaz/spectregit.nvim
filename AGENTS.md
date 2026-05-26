# spectregit.nvim — AGENTS.md

## What this is

Strangler Fig refactoring of [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive).
Original fugitive files (`plugin/fugitive.vim`, `autoload/fugitive.vim`, `doc/fugitive.txt`, etc.)
are **never modified**. A new `plugin/spectregit.vim` intercepts all public `Fugitive*()` and
`fugitive#*()` calls at `VimEnter` and routes them to `autoload/spectregit/*.vim` modules.

When a spectregit module is unavailable, the guard falls back to the original function.

## Architecture

```
plugin/fugitive.vim          ← NOT MODIFIED (source of originals to intercept)
autoload/fugitive.vim         ← NOT MODIFIED (8435-line monolith; source to port from)

plugin/spectregit.vim         ← FACADE — captures originals + installs guards
autoload/spectregit/
├── core.vim                  shared utilities (Dir, Tree, Slash, fnameescape, DirCommitFile, etc.)
├── statusline.vim            spectregit#statusline#Get()
├── fold.vim                  spectregit#fold#Text()
├── cd.vim                    spectregit#cd#Cd(), #Lcd(), #Complete()
├── quickfix.vim              spectregit#quickfix#Stream(), #Cwindow()
├── repo.vim                  spectregit#repo#New() — legacy repo prototype
├── complete.vim              spectregit#complete#CompletePath(), #Object(), #Heads(), #Sub(), etc.
├── git.vim                   spectregit#git#GitVersion(), #Head(), #RevParse(), #Autowrite(), #Wait()
├── path.vim                  spectregit#path#Parse(), #Real(), #Path()
└── config.vim                spectregit#config#Config(), #ConfigGetAll(), #Remote(), #SshConfig(), etc.
```

Not yet built: `autocmd.vim`, `edit.vim`, `write.vim`, `diff.vim`, `grep.vim`, `blame.vim`, `browse.vim`, `status.vim`, `maps.vim`.

## Naming convention

`spectregit#<module>#<Verb>()` — **no repetition** of the module name in the verb.
- Right: `spectregit#statusline#Get()`, `spectregit#config#Remote()`
- Wrong: `spectregit#statusline#StatuslineGet()`, `spectregit#config#ConfigRemote()`

Each autoload file guards itself with `g:autoloaded_spectregit_<module>`.

## Guard mechanism (plugin/spectregit.vim)

1. `augroup spectregit_init` fires `s:CaptureFugitiveOriginals()` at `VimEnter`
2. Inside capture: `call fugitive#GitVersion()` force-loads the autoload file so `function('fugitive#*')` captures work
3. All originals stored as `s:orig_<name>` via `function()` funcrefs
4. `s:InstallGuards()` redefines each function with: `if exists('*spectregit#<module>#<Verb>')` → spectregit, else → origin

**Key constraint**: VimEnter MUST fire before any guard function is called. Tests using `-c` commands run BEFORE VimEnter, so
guard functions are not active yet — originals are used directly.

## Porting from the monolith

The source file `autoload/fugitive.vim` (lines 1–8435) contains everything. When porting a section:
1. Create `autoload/spectregit/<module>.vim` with `<SID>` prefix guard
2. Copy the logic, but change `<SID>foo` calls to `spectregit#module#foo()` or internal `s:foo()` calls
3. Guard it in `plugin/spectregit.vim` — both in `CaptureFugitiveOriginals()` (capture) and `InstallGuards()` (redefine)
4. Functions that call monolith internals (e.g., `s:fugitive_UrlEncode`) should call the public facade instead (e.g., `fugitive#UrlEncode`)

## Testing

```vim
" Single -S script, NOT chained -c (avoids argument limits)
vim -T dumb -N -u NONE -i NONE -S /tmp/test_script.vim 2>&1
```

The test script handles `set rtp+=...`, `runtime! plugin/**/*.vim`, setup, and `cq`.

## Known gotchas

- `DirCommitFile` regex (`core.vim:188–191`) only matches 40-char hex hashes or `0`–`3` for the commit portion.
  Ref names like `HEAD` or `master` won't parse. This is matching actual fugitive URL generation behavior.
- `spectregit#core#fnameescape()` is a lazy-init cache function, not a script variable.
- `config.vim` does NOT redefine `fugitive#RemoteResolve` or `fugitive#SshHostAlias` — it delegates to originals.
- Some `fugitive#*()` internal autoload calls (e.g., `fugitive#UrlDecode` in `core.vim`, `fugitive#Wait` in `config.vim`)
  are still called from the ported modules — these MUST be guarded in `InstallGuards()` before they can be ported.
- `qfio` (Fugitive `BufReadCmd`/`BufWriteCmd`) is the largest remaining unported section (~750 lines in `autoload/fugitive.vim:2552–3302`).

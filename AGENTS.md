# spectregit.nvim — AGENTS.md

## What this is

Strangler Fig refactoring of [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive).
Original fugitive files (`plugin/fugitive.vim`, `autoload/fugitive.vim`, `doc/fugitive.txt`, etc.)
are **never modified**. A new `plugin/spectregit.vim` provides replacement autocmds and commands.

When a spectregit module is unavailable, the original fugitive function is called directly.

## Architecture

```
plugin/fugitive.vim          ← NOT MODIFIED (source of originals to intercept)
autoload/fugitive.vim         ← NOT MODIFIED (8435-line monolith; source to port from)

plugin/spectregit.vim         ← FACADE — replaces fugitive autocmds + adds G- commands
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
├── config.vim                spectregit#config#Config(), #ConfigGetAll(), #Remote(), #SshConfig(), etc.
└── autocmd.vim               spectregit#autocmd#BufReadCmd(), BufWriteCmd(), FileWriteCmd(), SourceCmd()
```

Not yet built: `edit.vim`, `write.vim`, `diff.vim`, `grep.vim`, `blame.vim`, `browse.vim`, `status.vim`, `maps.vim`.

## Naming convention

`spectregit#<module>#<Verb>()` — **no repetition** of the module name in the verb.
- Right: `spectregit#statusline#Get()`, `spectregit#config#Remote()`
- Wrong: `spectregit#statusline#StatuslineGet()`, `spectregit#config#ConfigRemote()`

Each autoload file guards itself with `g:autoloaded_spectregit_<module>`.

## Interception strategy (plugin/spectregit.vim)

**We do NOT redefine fugitive functions.** This approach was tried and failed due to:

1. **E746**: Vim 8.2+ prevents defining functions from other namespaces in plugin files
   (`Function name does not match script file name: fugitive#BufReadCmd`)
2. **`function('name')` resolves at call time**: Funcrefs captured before guard installation
   still resolve to the guard function after redefinition (not the original)
3. **`s:*` extraction is fragile**: `s:ExtractFunctionSource()` copies script-local references
   that break when re-executed in the plugin script context

Instead, we:
1. **Replace fugitive's autocmds** — remove fugitive's `BufReadCmd fugitive://*` and add our own
   that call `spectregit#autocmd#BufReadCmd()` directly
2. **Spectregit code calls originals directly** — ported spectregit functions like
   `spectregit#git#Execute` call `fugitive#Execute` (the original, since no guard exists)
3. **G- commands** are defined directly in `plugin/spectregit.vim` via `:exe 'command! ...'`

### BufReadCmd flow

```
Vim autocmd → fugitive://* → spectregit#autocmd#BufReadCmd()
  → calls fugitive#Execute() (original, no guard)
  → calls fugitive#PrepareJob() (original, no guard)
  → returns Ex command string that Vim executes in the buffer
```

## Porting from the monolith

The source file `autoload/fugitive.vim` (lines 1–8435) contains everything. When porting a section:
1. Create `autoload/spectregit/<module>.vim` with module guard
2. Copy the logic, change `s:foo()` calls to `spectregit#module#foo()` or internal `s:foo()` calls
3. Ported functions call fugitive originals directly by name (e.g., `fugitive#Execute()`)
4. For autocmd interception: no guard function needed — the autocmd replacement handles routing

## Testing

```vim
" Single -S script, NOT chained -c (avoids argument limits)
vim -T dumb -N -u NONE -i NONE -S /tmp/test_script.vim 2>&1
```

The test script handles `set rtp+=...`, `runtime! plugin/**/*.vim`, setup, and `cq`.

**Important**: `exists('*spectregit#module#Func')` does NOT trigger Vim autoload.
Call the function first to trigger autoload, then check existence.

## Known gotchas

- `DirCommitFile` regex (`core.vim:207–212`) only matches 40-char hex hashes or `0`–`3` for the commit portion.
  Ref names like `HEAD` or `master` won't parse. This is matching actual fugitive URL generation behavior.
- `spectregit#core#fnameescape()` is a lazy-init cache function, not a script variable.
- `config.vim` does NOT redefine `fugitive#RemoteResolve` or `fugitive#SshHostAlias` — it delegates to originals.
- `fugitive#*()` internal autoload calls ported modules use (e.g., `fugitive#UrlDecode`, `fugitive#Wait`)
  call the original functions directly (no guards).
- `qfio` (Fugitive `BufReadCmd`/`BufWriteCmd`) is the largest remaining unported section (~750 lines in `autoload/fugitive.vim:2552–3302`).
- `spectregit#git#GitVersion()` uses `system()` directly to avoid circular dependency
  with `spectregit#git#Execute` → `PrepareJob` → `PrepareDirEnvGitFlagsArgs` → `GitVersion`.

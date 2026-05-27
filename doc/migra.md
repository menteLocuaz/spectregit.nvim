# Strangler Fig Migration: Eliminating `autoload/fugitive.vim`

This document outlines the plan to decompose `autoload/fugitive.vim` into modular components under `autoload/spectregit/` and eventually eliminate the monolith.

## Current Status

- Functionality is being moved to `autoload/spectregit/`.
- Many modules already exist: `core.vim`, `git.vim`, `path.vim`, `config.vim`, `repo.vim`, etc.
- **High Coupling:** Most `spectregit#` modules still call `fugitive#` functions or use the `Fugitive*` global aliases (which call `fugitive#`).
- **Monolith Size:** `autoload/fugitive.vim` is still ~8400 lines long.

## Strategy: Strangler Fig Pattern

1. **Porting:** Move blocks of code from `fugitive.vim` to `spectregit/` modules.
2. **Decoupling:** Update `spectregit/` modules to call other `spectregit/` modules instead of `fugitive#`.
3. **Redirecting:** Update `fugitive#` functions to be thin wrappers around `spectregit#` equivalents.
4. **Elimination:** Once `fugitive.vim` contains only wrappers, it can be significantly reduced or removed if the public API is moved elsewhere.

## Phase 1: Porting Remaining Utilities & Core [COMPLETED]

### 1.1 IO & Path Utilities
Move the `io_fugitive` functions and path helpers to `spectregit#path` or `spectregit#core`.
- `fugitive#simplify`, `fugitive#resolve`
- `fugitive#getftime`, `fugitive#getfsize`, `fugitive#getftype`
- `fugitive#filereadable`, `fugitive#filewritable`, `fugitive#isdirectory`
- `fugitive#readfile`, `fugitive#writefile`
- `fugitive#glob`, `fugitive#delete`

### 1.2 Remote & SSH
Move remaining remote resolution logic to `spectregit#config`.
- `fugitive#RemoteHttpHeaders`
- `fugitive#RemoteResolve` (currently private in fugitive.vim)
- `fugitive#SshHostAlias`

## Phase 2: Decoupling `spectregit#` from `fugitive#`

Currently, `spectregit#` modules call `fugitive#` for core operations. This must be inverted.

- **`spectregit#core#Dir()`**: Should not call `FugitiveGitDir`. It should implement the detection logic or call a decoupled version.
- **`spectregit#core#Tree()`**: Should not call `FugitiveWorkTree`.
- **`spectregit#git#Execute()`**: Already exists but might still rely on `fugitive#PrepareJob`.
- **`spectregit#config#Config()`**: Should use `spectregit#git#Execute`.

**Target:** No `fugitive#` calls in `autoload/spectregit/*.vim`.

## Phase 3: Completion & Autocmds

- Move `fugitive#Complete*` to `spectregit#complete#*`.
- Move `fugitive#BufReadCmd`, etc. to `spectregit#autocmd#*` (mostly done, but verify).

## Phase 4: Feature Parity

Port the remaining large features:
- **Status/Index:** Ensure `spectregit#status` is fully independent.
- **Blame:** Ensure `spectregit#blame` is fully independent.
- **Diff:** Ensure `spectregit#diff` is fully independent.

## Phase 5: API Redirect & Cleanup

1. Update `autoload/fugitive.vim` functions to call `spectregit#`.
   ```vim
   function! fugitive#Execute(...) abort
     return call('spectregit#git#Execute', a:000)
   endfunction
   ```
2. Move global `Fugitive*` function definitions from `plugin/fugitive.vim` to `plugin/spectregit.vim` (as aliases to `spectregit#`).
3. Verify all tests pass with an empty `autoload/fugitive.vim`.
4. Delete `autoload/fugitive.vim`.

## Verification Plan

- Run existing tests: `themis test/`
- For each ported function, ensure a corresponding test exists in `test/modules/`.
- Use `test/integration/fugitive_untouched.test.vim` to ensure backward compatibility.

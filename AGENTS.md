# Repository Guidelines

## Project Structure & Module Organization

This repository is a personal Emacs configuration. `init.el` is the entry point and adds `lisp/`, `lisp/ide/`, and `themes/` to the relevant load paths before requiring feature modules. Core configuration lives in `lisp/init-*.el`; IDE-specific configuration is split under `lisp/ide/` by concern or language, for example `ide-common.el` and `ide-go.el`. Theme definitions live in `themes/`. Generated local state such as `elpa/`, `eln-cache/`, `backups/`, `auto-save-list/`, `history`, and `recentf` should stay untracked.

## Build, Test, and Development Commands

- `emacs --batch -l init.el`: load the full configuration in batch mode and catch startup errors.
- `emacs --batch -f batch-byte-compile lisp/*.el lisp/ide/*.el themes/*.el`: byte-compile tracked Elisp files and surface compiler warnings.
- `emacs --debug-init`: start interactively with detailed startup debugging when a batch load is not enough.

On a fresh machine, the first load may refresh package archives and install `use-package` plus declared packages from MELPA/GNU ELPA.

## Coding Style & Naming Conventions

Use Emacs Lisp conventions: two-space indentation, `lexical-binding: t` file headers for modules, and a final `(provide 'feature-name)` matching the file name. Name feature modules as `init-<area>.el` for top-level config and `ide-<area>.el` for IDE modules. Keep custom helper symbols under the `my/` prefix, as in `my/gopls-workspace-configuration`. Prefer `use-package` for package setup and keep key bindings close to the package configuration they affect.

## Testing Guidelines

There is no ERT suite in this repository. Validate changes by running the batch load command, then byte-compile the affected files. For interactive behavior, start `emacs --debug-init` and exercise the relevant package, mode, or key binding. When adding tests later, place them under `test/` with names like `init-completion-test.el` and document the command here.

## Commit & Pull Request Guidelines

Recent commits use short imperative or descriptive subjects, for example `disable repeat-map, enable meow` and `Refactoring IDE specific config`. Keep commit subjects concise and focused on one behavior or area. Pull requests should describe the user-visible editor change, list validation commands run, and mention any new package dependency or external tool requirement such as `gopls`, `delve`, or a formatter.

## Agent-Specific Instructions

Do not commit generated Emacs state or package directories. Keep edits scoped to tracked configuration files unless explicitly asked to migrate local state. Avoid network-dependent validation unless package installation or archive refresh is part of the requested change.

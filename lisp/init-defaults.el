;;; init-defaults.el --- Sensible default settings -*- lexical-binding: t -*-

;;; Commentary:
;; General Emacs behaviour and keybinding defaults.
;; Package-specific configuration belongs in its own init-*.el module.
;; This file should have no external package dependencies.

;;; Code:

;; ----------------------------------------------------------------------------
;; Startup
;; ----------------------------------------------------------------------------

;; Skip the default "Welcome to GNU Emacs" splash screen on startup.
(setq inhibit-startup-screen t)

;; ----------------------------------------------------------------------------
;; Custom file
;; ----------------------------------------------------------------------------

;; Emacs appends auto-generated customisation (from M-x customize) to init.el
;; by default, which pollutes your hand-written config. Redirect it to a
;; separate file instead. The file is created automatically if it doesn't exist.
(setq custom-file (locate-user-emacs-file "custom.el"))
;; Load it at startup, silently ignoring the case where it doesn't exist yet.
(load custom-file :no-error-if-file-is-missing)

;; ----------------------------------------------------------------------------
;; Auto-revert: keep buffers in sync with disk
;; ----------------------------------------------------------------------------

;; Automatically reload a file buffer when the file changes on disk (e.g.
;; after a git checkout or an external editor saves it). Without this you can
;; easily end up editing a stale buffer and overwriting newer changes.
(global-auto-revert-mode t)

;; Also auto-revert Dired and other non-file buffers (e.g. when files are
;; added or removed in a directory you have open).
(setq global-auto-revert-non-file-buffers t)

;; ----------------------------------------------------------------------------
;; Suppress noisy compilation/warning popups
;; ----------------------------------------------------------------------------

;; Prevent the *Warnings* and *Compile-Log* buffers from popping up a window
;; every time a package emits a warning during initialisation. They are still
;; accessible via M-x switch-to-buffer if you need to inspect them.
(add-to-list 'display-buffer-alist
             '("\\`\\*\\(Warnings\\|Compile-Log\\)\\*\\'"
               (display-buffer-no-window)
               (allow-no-window . t)))

;; ----------------------------------------------------------------------------
;; Editing defaults
;; ----------------------------------------------------------------------------

;; Enable repeat-mode
(repeat-mode 1)
;; Exit by pressing Return
(setq repeat-exit-key "RET")

;; Visual indicator in mode line that repeat is active
(setq repeat-echo-function #'repeat-echo-mode-line)


;; When a region is active and you start typing, replace the selected text
;; immediately (the behaviour you'd expect from virtually every other editor).
(use-package delsel
  :ensure nil ; Built-in package, no installation needed
  :hook (after-init . delete-selection-mode))

;; Store backup files (the foo.el~ files) in a single temp directory rather
;; than littering them next to the original files.
(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups" user-emacs-directory))))

;; Similarly, keep auto-save files (#foo.el#) out of your working directories.
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" user-emacs-directory) t)))

;; Follow symlinks to version-controlled files without asking every time.
(setq vc-follow-symlinks t)

;; Use spaces for indentation rather than tabs by default. Individual language
;; modes can override this where tabs are conventional (e.g. Go will set this
;; back to t via go-ts-mode).
(setq-default indent-tabs-mode nil)

;; Display line numbers in every buffer. `display-line-numbers-type' can be:
;;   t          — absolute line numbers
;;   'relative  — relative to the cursor (handy with evil-mode)
;;   'visual    — relative but counts screen lines, not logical lines
(setq display-line-numbers-type t)
(global-display-line-numbers-mode t)

;; Highlight the current line so it is easy to find your cursor position.
(global-hl-line-mode t)

;; ----------------------------------------------------------------------------
;; Keyboard quit — DWIM behaviour (credit: Protesilaos Stavrou / prot)
;; ----------------------------------------------------------------------------

;; The built-in C-g only quits in the focused context. This replacement makes
;; it smarter:
;;   - Active region    → deactivate the region (same as vanilla)
;;   - Unfocused minibuffer is open → close it without having to click away
;;   - Inside *Completions* buffer  → close that buffer
;;   - Anywhere else    → fall back to the regular keyboard-quit
(defun prot/keyboard-quit-dwim ()
  "Do-What-I-Mean behaviour for a general `keyboard-quit'.

The generic `keyboard-quit' does not do the expected thing when
the minibuffer is open.  Whereas we want it to close the
minibuffer, even without explicitly focusing it.

The DWIM behaviour of this command is as follows:
- When the region is active, disable it.
- When a minibuffer is open, but not focused, close the minibuffer.
- When the Completions buffer is selected, close it.
- In every other case use the regular `keyboard-quit'."
  (interactive)
  (cond
   ((region-active-p)
    (keyboard-quit))
   ((derived-mode-p 'completion-list-mode)
    (delete-completion-window))
   ((> (minibuffer-depth) 0)
    (abort-recursive-edit))
   (t
    (keyboard-quit))))

(define-key global-map (kbd "C-g") #'prot/keyboard-quit-dwim)

;; ----------------------------------------------------------------------------
;; Window navigation — windmove/winner-mode
;; ----------------------------------------------------------------------------

;; windmove lets you move between open windows (splits) using directional keys
;; rather than cycling through them with C-x o. With 'control as the modifier
;; the bindings become: C-<left>, C-<right>, C-<up>, C-<down>.
;;
;; Note: C-<left> and C-<right> are also bound to word-movement by default.
;; If that conflicts, consider using 'super (Windows/Cmd key) as the modifier
;; instead: (windmove-default-keybindings 'super)
(use-package windmove
  :ensure nil ; Built-in
  :config
  (windmove-default-keybindings 'control))

;; winner-mode records window configuration changes so you can undo/redo them.
(winner-mode t)

;; ----------------------------------------------------------------------------
;; Transparent sudo escalation for read-only files
;; ----------------------------------------------------------------------------

;; When opening a file you don't have write access to, automatically reopen it
;; via TRAMP's sudo method instead of silently opening a read-only buffer.
(advice-add 'find-file :after
  (lambda (&rest _)
    (when (and buffer-file-name
               (not (file-writable-p buffer-file-name)))
      (find-alternate-file
       (concat "/sudo:root@localhost:" buffer-file-name)))))

;; ----------------------------------------------------------------------------
;; Magit
;; ----------------------------------------------------------------------------

(use-package magit
  :ensure t)

;; ----------------------------------------------------------------------------
;; Direnv integration
;; ----------------------------------------------------------------------------

(use-package envrc
  :hook (after-init . envrc-global-mode))

(use-package inheritenv)

;; ----------------------------------------------------------------------------
;; Other defaults
;; ----------------------------------------------------------------------------

;; electric-pair-mode automatically inserts the delimiter pair (), {}, [], ""
;; when typing the opening delimiter
(electric-pair-mode 1)
(setq electric-pair-preserve-balance t)

;;; provide the feature so (require 'init-defaults) works from init.el
(provide 'init-defaults)

;;; init-defaults.el ends here

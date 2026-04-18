;;; init-completion.el --- Minibuffer and in-buffer completion -*- lexical-binding: t -*-

;;; Commentary:
;; Configures two complementary completion systems:
;;
;;  1. MINIBUFFER completion (M-x, find-file, buffers, etc.)
;;       Vertico  — the vertical candidate list UI
;;       Orderless — fuzzy/space-separated filtering style
;;       Marginalia — annotations alongside candidates (file size, docstring…)
;;       savehist   — persist minibuffer history across sessions
;;
;;  2. IN-BUFFER completion (code, prose)
;;       Corfu    — popup completion-at-point UI, fed by eglot/LSP in code
;;                  buffers and by dabbrev/cape elsewhere
;;
;; Load order requirement: this file must be required BEFORE init-ui.el
;; because vertico-posframe (in init-ui) depends on vertico being active.

;;; Code:

;; ----------------------------------------------------------------------------
;; savehist — persist minibuffer history across Emacs sessions
;; ----------------------------------------------------------------------------

;; Without savehist, your M-x and find-file history disappear on every
;; restart. With it, Emacs writes the history to disk and reloads it next
;; time. Several other packages (Vertico, Corfu) piggyback on this mechanism
;; to offer history-sorted candidates.
(use-package savehist
  :ensure nil ; built-in
  :hook (after-init . savehist-mode))

;; ----------------------------------------------------------------------------
;; Vertico — vertical minibuffer completion UI
;; ----------------------------------------------------------------------------

;; Vertico replaces the default horizontal completion list with a clean
;; vertical candidate list. It is intentionally minimal and delegates
;; filtering to orderless and annotations to marginalia.
(use-package vertico
  :hook (after-init . vertico-mode)
  :config
  ;; Number of candidates to show before scrolling.
  (setq vertico-count 15)

  ;; Cycle from the last candidate back to the first (and vice versa).
  (setq vertico-cycle t))

;; ----------------------------------------------------------------------------
;; Orderless — flexible, space-separated completion filtering
;; ----------------------------------------------------------------------------

;; Orderless lets you type parts of a candidate in any order, separated by
;; spaces. For example "buf swi" matches "switch-to-buffer". It also supports
;; regexp and literal component styles simultaneously.
(use-package orderless
  :config
  ;; Primary style: orderless (fuzzy, space-separated components).
  ;; Fallback: basic, required for TRAMP and some programmatic completions
  ;; that bypass the normal completion machinery.
  (setq completion-styles '(orderless basic))

  ;; Disable the per-category defaults that Emacs ships with; they would
  ;; partially override the styles above for files, buffers, etc.
  (setq completion-category-defaults nil)

  ;; No per-category overrides either — orderless handles everything.
  (setq completion-category-overrides nil))

;; ----------------------------------------------------------------------------
;; Marginalia — annotations in the minibuffer candidate list
;; ----------------------------------------------------------------------------

;; Marginalia adds useful context next to each candidate:
;;   - M-x        → one-line docstring for each command
;;   - find-file  → file size, permissions, modification date
;;   - describe-* → type information
;; It is also required by all-the-icons-completion (in init-ui.el) to hook
;; icons into the candidate list.
(use-package marginalia
  :hook (after-init . marginalia-mode))

;; ----------------------------------------------------------------------------
;; Corfu — in-buffer code completion popup
;; ----------------------------------------------------------------------------

;; Corfu is NOT a replacement for Vertico. It operates entirely inside file
;; buffers, showing a popup of completion-at-point candidates as you type.
;; In Go buffers (and any other language with an LSP server via eglot) it
;; displays method names, type completions, and signatures from gopls.
;;
;; Keybinding: <tab> confirms the selected candidate (or deepens the common
;; prefix if no single candidate is selected yet).
(use-package corfu
  :hook (after-init . global-corfu-mode)
  :bind (:map corfu-map
              ("<tab>" . corfu-complete))
  :config
  ;; Pressing TAB in a buffer first tries to indent; if the line is already
  ;; correctly indented it triggers completion instead.
  (setq tab-always-indent 'complete)

  ;; Don't show a live preview of the selected candidate inside the buffer —
  ;; it can be distracting while you are still typing.
  (setq corfu-preview-current nil)

  ;; Minimum popup width so it doesn't collapse on short completions.
  (setq corfu-min-width 20)

  ;; Delay before the documentation popup appears alongside the candidate
  ;; list: (seconds-when-moving . seconds-on-first-open).
  (setq corfu-popupinfo-delay '(1.25 . 0.5))

  ;; corfu-popupinfo shows the docstring / type signature of the highlighted
  ;; candidate in a secondary popup. Very useful for Go method signatures.
  (corfu-popupinfo-mode t)

  ;; Sort candidates by how recently/frequently you have selected them.
  ;; corfu-history records selections; savehist persists them to disk.
  (with-eval-after-load 'savehist
    (corfu-history-mode t)
    (add-to-list 'savehist-additional-variables 'corfu-history)))

;; ----------------------------------------------------------------------------
;; Cape — additional completion-at-point backends for Corfu
;; ----------------------------------------------------------------------------

;; Corfu only shows what the current buffer's completion-at-point functions
;; provide. Cape adds extra sources so you always have useful fallbacks even
;; outside LSP-enabled buffers.
(use-package cape
  :config
  ;; dabbrev: complete from words already present in any open buffer.
  ;; file:    complete filesystem paths when you type a / or ~.
  ;; These are prepended so they are available everywhere, including in
  ;; buffers where eglot is not running.
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))

;;; provide the feature so (require 'init-completion) works from init.el
(provide 'init-completion)

;;; init-completion.el ends here

;;; init-ui.el --- Visual appearance and UI configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Sets up the visual layer: theme, modeline, padding, icons, file tree,
;; minibuffer positioning, window management, and the startup dashboard.
;;
;; External dependencies (all from MELPA unless noted):
;;   doom-themes, doom-modeline, all-the-icons, all-the-icons-completion,
;;   treemacs, solaire-mode, golden-ratio, vertico-posframe, spacious-padding,
;;   dashboard
;;
;; First-time setup — run once after installing:
;;   M-x all-the-icons-install-fonts
;;   M-x nerd-icons-install-fonts   (required by doom-modeline >= 4.x)

;;; Code:

;; ----------------------------------------------------------------------------
;; Basics
;; ----------------------------------------------------------------------------

;; Disable the menu bar (File, Edit, Options... across the top)
(menu-bar-mode -1)

;; Disable the toolbar (the icon buttons below the menu bar)
(tool-bar-mode -1)

;; disable the UI scrollbar and replace with themed scrollbar
(scroll-bar-mode -1)
(use-package yascroll
  :config
  (setq yascroll:delay-to-hide nil)
  (global-yascroll-bar-mode t))

;; ----------------------------------------------------------------------------
;; Icons — all-the-icons
;; ----------------------------------------------------------------------------

;; all-the-icons provides the glyph font backend used by Dired, Treemacs, and
;; the dashboard. The fonts must be installed once with M-x
;; all-the-icons-install-fonts; after that they are picked up automatically.
(use-package all-the-icons
  :if (display-graphic-p)) ; Only load in GUI Emacs; irrelevant in terminal

;; Render icons next to files in Dired buffers.
(use-package all-the-icons-dired
  :after all-the-icons
  :hook (dired-mode . all-the-icons-dired-mode))

;; Hook all-the-icons into the completion UI (Vertico, Marginalia, etc.) so
;; that icons appear next to file candidates in the minibuffer.
(use-package all-the-icons-completion
  :after (all-the-icons marginalia)
  :hook (marginalia-mode . all-the-icons-completion-marginalia-setup)
  :config
  (all-the-icons-completion-mode t))

;; ----------------------------------------------------------------------------
;; Theme — doom-themes
;; ----------------------------------------------------------------------------

;; doom-themes is a large collection of well-maintained themes. We load
;; shades-of-purple, a vibrant dark theme with purple accents.
;;
;; treacle-bold / treacle-italic tweak heading rendering across modes;
;; enable both for a richer look.
(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-horizon t)

  ;; Correct the org-mode heading colours that some themes get wrong.
  (doom-themes-org-config))

;; ----------------------------------------------------------------------------
;; Solaire-mode — visually distinguish "real" file buffers
;; ----------------------------------------------------------------------------

;; solaire-mode makes auxiliary buffers (sidebars, popups, the minibuffer)
;; slightly darker than file-visiting buffers, giving a subtle depth cue that
;; helps you immediately identify where your code is. Works best with themes
;; that explicitly support it — doom-themes does.
(use-package solaire-mode
  :config
  (solaire-global-mode t))

;; ----------------------------------------------------------------------------
;; Spacious-padding — add breathing room around windows and the modeline
;; ----------------------------------------------------------------------------

;; Increases internal padding so that text doesn't crowd window edges and the
;; modeline. Purely cosmetic; does not affect any behaviour.
(use-package spacious-padding
  :config
  (setq spacious-padding-widths
        '(:internal-border-width 15   ; gap between the frame edge and content
          :header-line-width     4
          :mode-line-width       4    ; thicker modeline separator
          :tab-width             4
          :right-divider-width   1    ; thin line between side-by-side windows
          :scroll-bar-width      0    ; hide scroll bars (we use line numbers)
          :fringe-width          8))
  (spacious-padding-mode t))

;; ----------------------------------------------------------------------------
;; doom-modeline — feature-rich modeline
;; ----------------------------------------------------------------------------

;; doom-modeline requires nerd-icons for its glyphs (since v4). Install them
;; once with: M-x nerd-icons-install-fonts
(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :config
  ;; Height of the modeline bar (the coloured rectangle on the far left).
  (setq doom-modeline-height 32)

  ;; Show the column number next to the line number in the modeline.
  (setq doom-modeline-column-numbers t)

  ;; Truncate long buffer names in the middle rather than cutting the end off.
  (setq doom-modeline-buffer-name t)

  ;; Show the current project name (requires projectile or project.el).
  (setq doom-modeline-project-detection 'auto)

  ;; Display the active LSP server name — handy when working with eglot.
  (setq doom-modeline-lsp t)

  ;; Show the modal editing state (evil / meow / god); safe to leave on even
  ;; if you don't use modal editing — it simply stays blank then.
  (setq doom-modeline-modal t)

  ;; Show battery status if running on a laptop.
  (setq doom-modeline-battery t)

  ;; Show the time; set to nil if you prefer a clean modeline.
  (setq doom-modeline-time t))

;; ----------------------------------------------------------------------------
;; Vertico-posframe — float the minibuffer in the centre of the frame
;; ----------------------------------------------------------------------------

;; vertico-posframe renders the Vertico completion UI in a posframe (a child
;; frame) positioned in the middle of the screen rather than at the bottom.
;; This keeps your eyes near the code you are working on.
;;
;; Requires: vertico (configured in init-completion.el) and posframe.
(use-package vertico-posframe
  :after vertico
  :config
  ;; Centre the posframe both horizontally and vertically.
  (setq vertico-posframe-poshandler
        #'posframe-poshandler-frame-center)

  ;; Minimum width so the frame doesn't collapse on short inputs.
  (setq vertico-posframe-width  120
        vertico-posframe-height 20)

  ;; Add a subtle border so the frame stands out against the background.
  (setq vertico-posframe-border-width 2)

  (vertico-posframe-mode t))

;; ----------------------------------------------------------------------------
;; Golden-ratio — auto-resize windows so the focused one gets the most space
;; ----------------------------------------------------------------------------

;; golden-ratio automatically resizes Emacs windows so that the one you are
;; currently working in is sized according to the golden ratio (~61% of the
;; available space). Other windows shrink to give it room. The effect is that
;; focus naturally follows your attention without manual resizing.
;;
;; Treemacs is excluded so the sidebar stays at its fixed width.
(use-package golden-ratio
  :config
  (setq golden-ratio-exclude-modes
        '(treemacs-mode
          dired-mode
          ediff-mode
          help-mode
          apropos-mode
          special-mode
          dape-repl-mode
          dape-info-mode))

  ;; Also exclude special buffers whose width should not fluctuate.
  (setq golden-ratio-exclude-buffer-regexp
        '("\\*\\(Messages\\|Help\\|Warnings\\|dape-.*\\)\\*"))

  (golden-ratio-mode t))

;; ----------------------------------------------------------------------------
;; Treemacs — file/project tree sidebar
;; ----------------------------------------------------------------------------

(use-package treemacs
  :defer t ; Load only when first used, not at startup
  :config
  ;; Never let Emacs select the Treemacs window with `other-window' (C-x o).
  ;; You interact with Treemacs explicitly via F5, not by accident.
  (treemacs-is-never-other-window)

  ;; Automatically move focus in the tree to match the file you have open.
  (treemacs-project-follow-mode t)

  ;; Follow the currently playing file — mirrors project-follow but for the
  ;; active buffer rather than the active project root.
  (treemacs-filewatch-mode t)

  ;; Show thin git status indicators next to files and directories.
  (treemacs-git-mode 'deferred)

  ;; Collapse directories that contain only one child into a single node
  ;; (e.g. src/main/java/com/example becomes one collapsed entry).
  (setq treemacs-collapse-dirs 3)

  ;; Width of the sidebar in characters.
  (setq treemacs-width 35)

  ;; Toggle Treemacs with F5. Opens on the left if not visible; hides it if
  ;; already open.
  :bind
  ("<f5>" . treemacs))

;; ----------------------------------------------------------------------------
;; Dashboard — a useful startup screen
;; ----------------------------------------------------------------------------

;; Replaces the blank *scratch* buffer with a dashboard showing recent files,
;; projects, bookmarks, and agenda items.
(use-package dashboard
  :config
  (setq dashboard-banner-logo-title "Welcome back."
        ;; Use the Emacs logo as the banner; alternatives:
        ;;   'official — the official GNU Emacs logo
        ;;   'text     — ASCII art text banner
        ;;   "~/path"  — a custom image file
        dashboard-startup-banner     'logo

        ;; Items to display and how many entries each section shows.
        dashboard-items '((recents   . 8)
                          (projects  . 5)
                          (bookmarks . 5)
                          (agenda    . 5))

        ;; Show icons next to each section heading and each item.
        dashboard-display-icons-p     t
        dashboard-icon-type           'all-the-icons
        dashboard-set-heading-icons   t
        dashboard-set-file-icons      t

        ;; Show the Emacs init load time at the bottom.
        dashboard-set-init-info       t

        ;; Centre all dashboard content horizontally.
        dashboard-center-content      t)

  (dashboard-setup-startup-hook))

;; ----------------------------------------------------------------------------
;; Side windows — pin help/doc buffers to the bottom of the frame
;; ----------------------------------------------------------------------------

(defun my-switch-to-window (window)
  (select-window window))

;; Help, documentation and diagnostic buffers open as side windows at the
;; bottom. Side windows are excluded from golden-ratio resizing by design
;; and stay at a fixed height regardless of which window has focus.
(add-to-list 'display-buffer-alist
             '("\\*\\(Help\\|describe-char\\|Apropos\\|eldoc\\|xref\\|Flymake\\|compilation\\|Messages\\|Embark Actions\\)\\*"
               (display-buffer-reuse-window
                display-buffer-in-side-window)
               (side . bottom)
               (slot . 0)
               (window-height . 0.35)
               (inhibit-same-window . t)))

(add-to-list 'display-buffer-alist
             '("\\*Occur\\*"
               (display-buffer-reuse-window
                display-buffer-below-selected)
               (dedicated . t)
               (body-function . my-switch-to-window)))

;; ----------------------------------------------------------------------------
;; Other
;; ----------------------------------------------------------------------------

;; Disable line numbers in buffers where they add no value.
(dolist (hook '(treemacs-mode-hook
                dashboard-mode-hook
                dired-mode-hook
                help-mode-hook
                special-mode-hook))
  (add-hook hook (lambda () (display-line-numbers-mode -1))))

;;; provide the feature so (require 'init-ui) works from init.el
(provide 'init-ui)

;;; init-ui.el ends here

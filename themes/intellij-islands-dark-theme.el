;;; intellij-islands-dark-theme.el --- IntelliJ New UI inspired theme -*- lexical-binding: t -*-

;; Author: Generated from IntelliJ New UI screenshot
;; Version: 1.0
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;; A dark theme matching IntelliJ IDEA's New UI dark theme colors,
;; tuned for Go development with go-ts-mode, eglot semantic tokens,
;; Corfu, Vertico, Marginalia, Treemacs, and doom-modeline.
;;
;; Installation:
;;   Place in your load-path, e.g. ~/.config/emacs/themes/
;;   Add to init.el:
;;     (add-to-list 'custom-theme-load-path "~/.config/emacs/themes/")
;;     (load-theme 'intellij-islands-dark t)

;;; Code:

(deftheme intellij-islands-dark
  "IntelliJ New UI dark theme for Emacs 29+ with tree-sitter support.")

;;; Palette
;; All colors extracted from IntelliJ New UI dark screenshot.
(let* (
       ;; --- Editor background & chrome ---
       (bg-default    "#1e1f22")   ; main editor background
       (bg-alt        "#26282e")   ; current line highlight, secondary panels
       (bg-highlight  "#2b2d33")   ; subtle highlight (e.g. region, hover)
       (bg-selection  "#214283")   ; visual selection / mark region
       (bg-modeline   "#2c2e34")   ; mode line background
       (bg-fringe     "#1e1f22")   ; fringe (same as bg)
       (bg-popup      "#2b2d30")   ; completion popup background (Corfu)
       (bg-tooltip    "#1e1f22")   ; eldoc tooltip

       ;; --- Foreground ---
       (fg-default    "#cccccc")   ; default text, parameters, plain identifiers
       (fg-dim        "#7a8090")   ; dimmed text, unused symbols
       (fg-very-dim   "#4e5157")   ; line numbers, very subtle UI

       ;; --- Syntax: keywords & built-in types ---
       (keyword       "#cf8e6d")   ; func, type, return, struct, var, const, etc.
                                        ; also built-in types: string, int, bool, byte

       ;; --- Syntax: functions & methods ---
       (func-def      "#56a8f5")   ; function/method name at definition site
       (func-call     "#af9673")   ; function/method call
       (func-unused   "#6b7280")   ; unreferenced function (IntelliJ greys these out)

       ;; --- Syntax: types & namespaces ---
       (type-name     "#2acadf")   ; type names, struct names, interface names
       (namespace     "#d8cc65")   ; package qualifiers (ast., models., builder.)

       ;; --- Syntax: values ---
       (string        "#6aab73")   ; string literals
       (number        "#2aacb8")   ; numeric literals, also int64/float64 in type args
       (constant      "#cf8e6d")   ; true, false, nil, iota (same as keyword)
       (operator      "#c8ccd4")   ; operators: =, :=, ., ->, +, etc.

       ;; --- Comments ---
       (comment       "#7a8090")   ; regular comments
       (doc-comment   "#629755")   ; godoc comments (slightly greener)

       ;; --- Inlay hints ---
       (inlay-fg      "#7a8799")   ; inlay hint text (parameter names, type hints)
       (inlay-bg      "#2e3037")   ; inlay hint background box

       ;; --- UI: errors & diagnostics ---
       (error-fg      "#f44747")   ; errors (red underline / text)
       (warning-fg    "#e0a060")   ; warnings
       (info-fg       "#56a8f5")   ; info / hints
       (success-fg    "#6aab73")   ; success

       ;; --- UI: diff & version control ---
       (diff-add      "#294436")   ; added line background
       (diff-del      "#3c2626")   ; deleted line background
       (diff-change   "#2e3a4a")   ; changed line background
       (diff-add-fg   "#6aab73")   ; added text
       (diff-del-fg   "#f44747")   ; deleted text

       ;; --- UI: modeline ---
       (modeline-fg       "#c8ccd4")
       (modeline-fg-dim   "#7a8090")
       (modeline-bg       "#2c2e34")
       (modeline-bg-alt   "#1e1f22")
       (modeline-accent   "#56a8f5")

       ;; --- UI: minibuffer & completion ---
       (match-fg      "#56a8f5")   ; matching characters in Vertico/Orderless
       (match-bg      "#1d3557")   ; match background
       )

  (custom-theme-set-faces
   'intellij-islands-dark

   ;; =========================================================
   ;; 1. BASIC FACES
   ;; =========================================================
   `(default                    ((t (:background ,bg-default :foreground ,fg-default))))
   `(cursor                     ((t (:background ,fg-default))))
   `(fringe                     ((t (:background ,bg-fringe :foreground ,fg-very-dim))))
   `(region                     ((t (:background ,bg-selection :extend t))))
   `(highlight                  ((t (:background ,bg-highlight))))
   `(hl-line                    ((t (:background ,bg-alt :extend t))))
   `(line-number                ((t (:background ,bg-default :foreground ,fg-very-dim))))
   `(line-number-current-line   ((t (:background ,bg-alt :foreground ,fg-dim :weight bold))))
   `(vertical-border            ((t (:foreground "#3a3c42"))))
   `(window-divider             ((t (:foreground "#3a3c42"))))
   `(minibuffer-prompt          ((t (:foreground ,func-def :weight bold))))
   `(secondary-selection        ((t (:background ,bg-highlight))))
   `(trailing-whitespace        ((t (:background ,error-fg))))
   `(link                       ((t (:foreground ,func-def :underline t))))
   `(link-visited               ((t (:foreground ,type-name :underline t))))
   `(bold                       ((t (:weight bold))))
   `(italic                     ((t (:slant italic))))
   `(shadow                     ((t (:foreground ,fg-dim))))
   `(success                    ((t (:foreground ,success-fg :weight bold))))
   `(warning                    ((t (:foreground ,warning-fg :weight bold))))
   `(error                      ((t (:foreground ,error-fg :weight bold))))

   ;; =========================================================
   ;; 2. FONT-LOCK (standard syntax highlighting)
   ;; =========================================================
   `(font-lock-keyword-face          ((t (:foreground ,keyword))))
   `(font-lock-type-face             ((t (:foreground ,type-name))))
   `(font-lock-builtin-face          ((t (:foreground ,keyword))))     ; built-in funcs: make, len, append
   `(font-lock-function-name-face    ((t (:foreground ,func-def :weight bold))))
   `(font-lock-function-call-face    ((t (:foreground ,func-call))))   ; Emacs 29+ call face
   `(font-lock-variable-name-face    ((t (:foreground ,fg-default))))
   `(font-lock-variable-use-face     ((t (:foreground ,fg-default))))
   `(font-lock-constant-face         ((t (:foreground ,constant))))
   `(font-lock-string-face           ((t (:foreground ,string))))
   `(font-lock-doc-face              ((t (:foreground ,doc-comment :slant italic))))
   `(font-lock-comment-face          ((t (:foreground ,comment :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,comment :slant italic))))
   `(font-lock-number-face           ((t (:foreground ,number))))
   `(font-lock-operator-face         ((t (:foreground ,operator))))
   `(font-lock-punctuation-face      ((t (:foreground ,fg-default))))
   `(font-lock-bracket-face          ((t (:foreground ,fg-default))))
   `(font-lock-delimiter-face        ((t (:foreground ,fg-default))))
   `(font-lock-property-name-face    ((t (:foreground ,fg-default))))   ; struct field defs
   `(font-lock-property-use-face     ((t (:foreground ,namespace))))    ; package qualifiers
   `(font-lock-escape-face           ((t (:foreground ,keyword))))
   `(font-lock-warning-face          ((t (:foreground ,warning-fg :weight bold))))
   `(font-lock-negation-char-face    ((t (:foreground ,keyword))))
   `(font-lock-preprocessor-face     ((t (:foreground ,keyword))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,string))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,string))))

   ;; =========================================================
   ;; 3. EGLOT (LSP)
   ;; =========================================================
   `(eglot-highlight-symbol-face   ((t (:background ,bg-highlight :underline nil))))
   `(eglot-diagnostic-tag-unnecessary-face ((t (:foreground ,fg-dim :slant italic))))
   `(eglot-diagnostic-tag-deprecated-face  ((t (:foreground ,fg-dim :strike-through t))))

   ;; Inlay hints — match IntelliJ's subtle greyed parameter labels
   `(eglot-inlay-hint-face         ((t (:foreground ,inlay-fg ;:background ,inlay-bg
                                                    :slant italic :height 0.80))))
   `(eglot-type-hint-face          ((t (:inherit eglot-inlay-hint-face))))
   `(eglot-parameter-hint-face     ((t (:inherit eglot-inlay-hint-face))))

   ;; =========================================================
   ;; 4. EGLOT SEMANTIC FACES
   ;; =========================================================
   ;; Token types (as reported by gopls via eglot):
   `(eglot-semantic-namespace     ((t (:foreground ,namespace))))
   `(eglot-semantic-type          ((t (:foreground ,type-name))))
   `(eglot-semantic-class         ((t (:foreground ,type-name))))
   `(eglot-semantic-interface     ((t (:foreground ,type-name))))
   `(eglot-semantic-struct        ((t (:foreground ,type-name))))
   `(eglot-semantic-enum          ((t (:foreground ,type-name))))
   `(eglot-semantic-enumMember    ((t (:foreground ,constant))))
   `(eglot-semantic-typeParameter ((t (:foreground ,type-name :slant italic))))
   `(eglot-semantic-parameter     ((t (:foreground ,fg-default))))
   `(eglot-semantic-variable      ((t (:foreground ,fg-default))))
   `(eglot-semantic-property      ((t (:foreground ,fg-default))))
   `(eglot-semantic-function      ((t (:foreground ,func-call))))
   `(eglot-semantic-method        ((t (:foreground ,func-call))))
   `(eglot-semantic-event         ((t (:foreground ,func-call))))
   `(eglot-semantic-macro         ((t (:foreground ,keyword))))
   `(eglot-semantic-keyword       ((t (:foreground ,keyword))))
   `(eglot-semantic-modifier      ((t (:foreground ,keyword))))
   `(eglot-semantic-comment       ((t (:foreground ,comment :slant italic))))
   `(eglot-semantic-documentation ((t (:foreground ,doc-comment :slant italic))))
   `(eglot-semantic-string        ((t (:foreground ,string))))
   `(eglot-semantic-number        ((t (:foreground ,number))))
   `(eglot-semantic-operator      ((t (:foreground ,operator))))
   `(eglot-semantic-regexp        ((t (:foreground ,string))))
   `(eglot-semantic-decorator     ((t (:foreground ,fg-dim))))
   
   ;; Modifier faces (applied on top of token type faces):
   `(eglot-semantic-definition    ((t (:weight bold))))
   `(eglot-semantic-declaration   ((t (:weight bold))))
   `(eglot-semantic-readonly      ((t (:foreground ,constant))))
   `(eglot-semantic-static        ((t (:slant italic))))
   `(eglot-semantic-abstract      ((t (:slant italic))))
   `(eglot-semantic-async         ((t (:slant italic))))
   `(eglot-semantic-deprecated    ((t (:strike-through t :foreground ,fg-dim))))
   `(eglot-semantic-modification  ((t (:foreground ,warning-fg))))
   `(eglot-semantic-defaultLibrary ((t (:foreground ,keyword))))

   ;; =========================================================
   ;; 5. FLYMAKE / DIAGNOSTICS
   ;; =========================================================
   `(flymake-error   ((t (:underline (:style wave :color ,error-fg)))))
   `(flymake-warning ((t (:underline (:style wave :color ,warning-fg)))))
   `(flymake-note    ((t (:underline (:style wave :color ,info-fg)))))

   ;; =========================================================
   ;; 6. CORFU (in-buffer completion)
   ;; =========================================================
   `(corfu-default      ((t (:background ,bg-popup :foreground ,fg-default))))
   `(corfu-current      ((t (:background ,bg-selection :foreground ,fg-default :weight bold))))
   `(corfu-bar          ((t (:background ,modeline-accent))))
   `(corfu-border       ((t (:background "#3a3c42"))))
   `(corfu-annotations  ((t (:foreground ,fg-dim))))
   `(corfu-deprecated   ((t (:foreground ,fg-dim :strike-through t))))
   `(corfu-echo         ((t (:foreground ,fg-dim :slant italic))))

   ;; =========================================================
   ;; 7. VERTICO (minibuffer completion)
   ;; =========================================================
   `(vertico-current    ((t (:background ,bg-selection :extend t))))

   ;; =========================================================
   ;; 8. ORDERLESS (completion matching)
   ;; =========================================================
   `(orderless-match-face-0 ((t (:foreground ,func-def :weight bold))))
   `(orderless-match-face-1 ((t (:foreground ,type-name :weight bold))))
   `(orderless-match-face-2 ((t (:foreground ,string :weight bold))))
   `(orderless-match-face-3 ((t (:foreground ,number :weight bold))))

   ;; =========================================================
   ;; 9. MARGINALIA (annotations in minibuffer)
   ;; =========================================================
   `(marginalia-key         ((t (:foreground ,func-def))))
   `(marginalia-type        ((t (:foreground ,type-name))))
   `(marginalia-char        ((t (:foreground ,string))))
   `(marginalia-lighter     ((t (:foreground ,fg-dim))))
   `(marginalia-documentation ((t (:foreground ,fg-dim :slant italic))))
   `(marginalia-value       ((t (:foreground ,fg-default))))
   `(marginalia-null        ((t (:foreground ,fg-dim))))
   `(marginalia-true        ((t (:foreground ,success-fg))))
   `(marginalia-false       ((t (:foreground ,error-fg))))
   `(marginalia-file-name   ((t (:foreground ,fg-default))))
   `(marginalia-file-owner  ((t (:foreground ,fg-dim))))
   `(marginalia-file-priv-no ((t (:foreground ,fg-very-dim))))

   ;; =========================================================
   ;; 10. DOOM-MODELINE
   ;; =========================================================
   `(mode-line              ((t (:background ,modeline-bg :foreground ,modeline-fg
                                             :box (:line-width 1 :color "#3a3c42")))))
   `(mode-line-inactive     ((t (:background ,modeline-bg-alt :foreground ,modeline-fg-dim
                                             :box (:line-width 1 :color "#2e3036")))))
   `(mode-line-highlight    ((t (:background ,bg-highlight))))
   `(mode-line-buffer-id    ((t (:foreground ,func-def :weight bold))))

   `(doom-modeline-buffer-file        ((t (:foreground ,fg-default :weight bold))))
   `(doom-modeline-buffer-modified    ((t (:foreground ,warning-fg :weight bold))))
   `(doom-modeline-buffer-major-mode  ((t (:foreground ,type-name :weight bold))))
   `(doom-modeline-project-dir        ((t (:foreground ,func-def))))
   `(doom-modeline-branch-name        ((t (:foreground ,namespace))))
   `(doom-modeline-info               ((t (:foreground ,success-fg))))
   `(doom-modeline-warning            ((t (:foreground ,warning-fg))))
   `(doom-modeline-urgent             ((t (:foreground ,error-fg))))
   `(doom-modeline-error              ((t (:foreground ,error-fg))))
   `(doom-modeline-lsp-success        ((t (:foreground ,success-fg))))
   `(doom-modeline-lsp-warning        ((t (:foreground ,warning-fg))))
   `(doom-modeline-lsp-error          ((t (:foreground ,error-fg))))

   ;; =========================================================
   ;; 11. TREEMACS
   ;; =========================================================
   `(treemacs-root-face              ((t (:foreground ,func-def :weight bold :height 1.1))))
   `(treemacs-directory-face         ((t (:foreground ,fg-default))))
   `(treemacs-directory-collapsed-face ((t (:foreground ,fg-default))))
   `(treemacs-file-face              ((t (:foreground ,fg-default))))
   `(treemacs-git-modified-face      ((t (:foreground ,warning-fg))))
   `(treemacs-git-added-face         ((t (:foreground ,success-fg))))
   `(treemacs-git-deleted-face       ((t (:foreground ,error-fg))))
   `(treemacs-git-untracked-face     ((t (:foreground ,fg-dim))))
   `(treemacs-git-ignored-face       ((t (:foreground ,fg-very-dim))))
   `(treemacs-fringe-indicator-face  ((t (:foreground ,modeline-accent))))
   `(treemacs-on-success-pulse-face  ((t (:background ,diff-add))))
   `(treemacs-on-failure-pulse-face  ((t (:background ,diff-del))))

   ;; =========================================================
   ;; 12. ISEARCH & REPLACE
   ;; =========================================================
   `(isearch           ((t (:background "#4a5568" :foreground ,fg-default :weight bold))))
   `(isearch-fail      ((t (:background ,diff-del :foreground ,error-fg))))
   `(lazy-highlight    ((t (:background "#2d3748" :foreground ,fg-default))))
   `(match             ((t (:background ,match-bg :foreground ,match-fg :weight bold))))

   ;; =========================================================
   ;; 13. DIFF / VC
   ;; =========================================================
   `(diff-added       ((t (:background ,diff-add :foreground ,diff-add-fg :extend t))))
   `(diff-removed     ((t (:background ,diff-del :foreground ,diff-del-fg :extend t))))
   `(diff-changed     ((t (:background ,diff-change :extend t))))
   `(diff-header      ((t (:background ,bg-alt :foreground ,fg-dim))))
   `(diff-file-header ((t (:background ,bg-alt :foreground ,fg-default :weight bold))))
   `(diff-hunk-header ((t (:background ,bg-alt :foreground ,namespace))))

   `(vc-state-base            ((t (:foreground ,fg-dim))))
   `(vc-edited-state          ((t (:foreground ,warning-fg))))
   `(vc-needs-update-state    ((t (:foreground ,info-fg))))
   `(vc-conflict-state        ((t (:foreground ,error-fg :weight bold))))
   `(vc-locally-added-state   ((t (:foreground ,success-fg))))
   `(vc-missing-state         ((t (:foreground ,error-fg))))
   `(vc-removed-state         ((t (:foreground ,error-fg))))

   ;; =========================================================
   ;; 14. XREF
   ;; =========================================================
   `(xref-match       ((t (:background ,match-bg :foreground ,match-fg :weight bold))))
   `(xref-file-header ((t (:foreground ,func-def :weight bold))))
   `(xref-line-number ((t (:foreground ,fg-very-dim))))

   ;; =========================================================
   ;; 15. WHICH-KEY
   ;; =========================================================
   `(which-key-key-face                   ((t (:foreground ,func-def))))
   `(which-key-separator-face             ((t (:foreground ,fg-very-dim))))
   `(which-key-command-description-face   ((t (:foreground ,fg-default))))
   `(which-key-local-map-description-face ((t (:foreground ,type-name))))
   `(which-key-group-description-face     ((t (:foreground ,namespace :weight bold))))

   ;; =========================================================
   ;; 16. DAPE / DAP (debugger)
   ;; =========================================================
   `(dape-breakpoint-face         ((t (:foreground ,error-fg))))
   `(dape-stack-trace-pointer     ((t (:foreground ,warning-fg :weight bold))))

   ;; =========================================================
   ;; 17. COMPILATION BUFFER
   ;; =========================================================
   `(compilation-error    ((t (:foreground ,error-fg :weight bold))))
   `(compilation-warning  ((t (:foreground ,warning-fg :weight bold))))
   `(compilation-info     ((t (:foreground ,info-fg))))
   `(compilation-line-number ((t (:foreground ,number))))
   `(compilation-column-number ((t (:foreground ,number))))
   `(compilation-mode-line-exit ((t (:foreground ,success-fg :weight bold))))
   `(compilation-mode-line-fail ((t (:foreground ,error-fg :weight bold))))

   ;; =========================================================
   ;; 18. ELDOC-BOX (floating docs)
   ;; =========================================================
   `(eldoc-box-body          ((t (:background ,bg-popup :foreground ,fg-default))))
   `(eldoc-box-border        ((t (:background "#3a3c42"))))

   ;; =========================================================
   ;; 19. SPACIOUS-PADDING / SOLAIRE-MODE
   ;; =========================================================
   `(solaire-default-face    ((t (:background "#191a1d"))))
   `(solaire-hl-line-face    ((t (:background "#222428"))))

   ;; =========================================================
   ;; 20. DASHBOARD
   ;; =========================================================
   `(dashboard-banner-logo-title ((t (:foreground ,func-def :weight bold))))
   `(dashboard-heading           ((t (:foreground ,type-name :weight bold))))
   `(dashboard-items-face        ((t (:foreground ,fg-default))))
   `(dashboard-no-items-face     ((t (:foreground ,fg-dim))))
   `(dashboard-footer-face       ((t (:foreground ,fg-very-dim :slant italic))))
   ))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-directory load-file-name)))

(provide-theme 'intellij-islands-dark)

;;; intellij-islands-dark-theme.el ends here

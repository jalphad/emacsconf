;;; ide-common.el --- Common IDE configuration -*- lexical-binding: t -*-

;; ----------------------------------------------------------------------------
;; eglot — built-in LSP client
;; ----------------------------------------------------------------------------

;; eglot ships with Emacs 29 and connects go-ts-mode to gopls, providing:
;;   - completions (fed into Corfu)
;;   - diagnostics (inline errors/warnings)
;;   - go-to-definition (M-.)
;;   - find-references (M-?)
;;   - rename symbol (M-x eglot-rename)
;;   - code actions (M-x eglot-code-actions) — e.g. fill struct, add import
;;   - hover documentation (eldoc, shown in the echo area or a child frame)

;; Gopls configuration for eglot needs to be defined before eglot loads.
(defun my/gopls-settings ()
  "Return gopls settings shared by initialization and workspace configuration."
  '(;; --- Snippets & Completion ---
    ;; Enables placeholders in function signatures (e.g., func(name string)).
    ;; This is crucial for Yasnippet integration.
    :usePlaceholders t
    ;; Allows gopls to suggest symbols from packages you haven't imported yet.
    :completeUnimported t
    ;; Ask gopls to advertise semantic token support during initialization.
    :semanticTokens t

    ;; --- Code Analysis ---
    ;; Detailed analysis passes for catching logic errors.
    :analyses (:unusedparams t      ; Warn about unused function parameters
                             :unusedvariable t    ; Warn about variables declared but not used
                             :unusedwrite t       ; Warn about writes to variables that are never read
                             :shadow t)           ; Warn when a variable shadows one in an outer scope

    ;; --- Inlay Hints ---
    ;; Visual annotations in the editor (Toggle with M-x eglot-inlay-hints-mode).
    :hints (:parameterNames t            ; Show parameter names in function calls
                            :assignVariableTypes t       ; Show inferred types for variable assignments
                            :compositeLiteralFields t)   ; Show field names in struct literals

    ;; --- Formatting & Linting ---
    ;; We use apheleia for formatting instead of eglot/gopls
    ;; :gofumpt t
    ;; Runs staticcheck.io linters for even deeper code analysis.
    :staticcheck t))

(defun my/gopls-workspace-configuration ()
  "Return gopls workspace configuration for eglot."
  `(:gopls ,(my/gopls-settings)))

(use-package eglot
  :ensure t ; don't use the bundled version but pull latest from GNU Elpa
  :pin gnu
  :demand t
  ;; :hook (go-ts-mode . eglot-ensure)
  ;; :after go-ts-mode
  :config
  ;; Shut down the gopls server when the last Go buffer is closed rather than
  ;; keeping it alive forever in the background.
  (setq eglot-autoshutdown t)

  ;; Show all of eldoc's information (hover docs, signature, diagnostics)
  ;; rather than truncating to one line in the echo area.
  (setq eldoc-echo-area-use-multiline-p nil) ; keep echo area clean ...

  ;; Integrate gopls with eglot
  ;; Pass semantic token configuration during initialization so gopls advertises
  ;; the semantic token provider before Eglot decides which modes to enable.
  ;; These mirror gopls' settings documented at:
  ;; https://github.com/golang/tools/blob/master/gopls/doc/settings.md  
  (add-to-list 'eglot-server-programs
               `((go-mode go-dot-mod-mode go-dot-work-mode
                          go-ts-mode go-mod-ts-mode go-work-ts-mode)
                 . ("gopls" :initializationOptions ,(my/gopls-settings))))
  (setq-default eglot-workspace-configuration
                (my/gopls-workspace-configuration))

  ;; ... and use eldoc-box for a floating child-frame doc popup instead.
  ;; Remove this block if you prefer the echo area.
  :bind (:map eglot-mode-map
              ("C-c r"   . eglot-rename)           ; rename symbol at point
              ("C-c a"   . eglot-code-actions)      ; code actions (add import etc.)
              ("C-c f"   . eglot-format-buffer)     ; manual format
              ("C-c d"   . eldoc)                   ; show docs at point
              ("M-."     . xref-find-definitions)   ; go to definition
              ("M-,"     . xref-pop-marker-stack)   ; jump back
              ("M-?"     . xref-find-references)))  ; find all references

;; (with-eval-after-load 'eglot
;;   (add-hook 'eglot-managed-mode-hook
;;             (lambda ()
;;               ;; Type at definition site: use default text color, not purple
;;               (set-face-attribute 'eglot-semantic-type/definition nil
;;                                   :foreground (face-attribute 'default :foreground nil t)
;;                                   :inherit nil)
;;               ;; Function at definition site: use func-def color (bold blue)
;;               (set-face-attribute 'eglot-semantic-function/definition nil
;;                                   :foreground (face-attribute 'font-lock-function-name-face
;;                                                               :foreground nil t)
;;                                   :weight 'bold
;;                                   :inherit nil))))

;; (custom-set-faces
;;  '(eglot-inlay-hint-face ((t (:foreground "#7a8799" :slant italic :height 0.80))))
;;  '(eglot-type-hint-face  ((t (:inherit eglot-inlay-hint-face :foreground "#7a8799"))))
;;  '(eglot-parameter-hint-face ((t (:inherit eglot-inlay-hint-face :foreground "#7a8799")))))

;; eldoc-box renders the hover documentation in a neat child frame rather
;; than the cramped echo area. Works with any eldoc provider, including eglot.
(use-package eldoc-box
  :after eglot
  :hook (eglot-managed-mode . eldoc-box-hover-mode))

;; ----------------------------------------------------------------------------
;; Apheleia — non-blocking, asynchronous code formatting
;; ----------------------------------------------------------------------------

;; Apheleia runs formatters in the background and applies the diff to the
;; buffer without moving your cursor or blocking the UI.
(use-package apheleia
  :ensure t
  :config
  (apheleia-global-mode t))

;; ----------------------------------------------------------------------------
;; Dape — Debug Adapter Protocol client (uses delve for Go)
;; ----------------------------------------------------------------------------

;; Dape is a modern DAP client. For Go it talks to delve. Key bindings follow
;; a consistent prefix so muscle memory transfers across languages.
;;
;; Typical debug workflow:
;;   1. Place a breakpoint with C-c b b
;;   2. Launch with C-c b d (debug current file) or C-c b t (debug test at point)
;;   3. Step with C-c b n (next), C-c b i (step in), C-c b o (step out)
;;   4. Inspect locals in the *dape-repl* buffer
;;   5. Quit with C-c b q

(defvar my/pre-debug-window-config nil
  "Window configuration saved before a dape debug session starts.")

(defun my/restore-debug-windows ()
  "Restore window configuration saved before the last dape debug session."
  (interactive)
  (if my/pre-debug-window-config
      (progn
        (set-window-configuration my/pre-debug-window-config)
        (setq my/pre-debug-window-config nil)
        (message "Window configuration restored"))
    (message "No saved window configuration to restore")))

(use-package dape
  :config
  ;; Save window configuration before debug session so it can easily be restored after
  (add-hook 'dape-on-start-hooks
            (lambda ()
              (setq my/pre-debug-window-config
                    (current-window-configuration))
              (delete-other-windows)))

  ;; Save all modified buffers before starting a debug session so you are
  ;; always debugging the code you see on screen.
  (setq dape-buffer-window-arrangement 'right)
  
  :bind
  (("C-c b b" . dape-breakpoint-toggle)   ; C-c b b — toggle breakpoint    
   ("C-c b d" . dape)                     ; C-c b d — start / choose config
   ("C-c b n" . dape-next)                ; C-c b n — step over            
   ("C-c b i" . dape-step-in)             ; C-c b i — step into            
   ("C-c b o" . dape-step-out)            ; C-c b o — step out             
   ("C-c b c" . dape-continue)            ; C-c b c — continue             
   ("C-c b r" . dape-restart)             ; C-c b r — restart session      
   ("C-c b q" . dape-quit)                ; C-c b q — end session          
   ("C-c b e" . dape-eval)                ; C-c b e — eval expression      
   ("C-c b l" . dape-repl)                ; C-c b l — open REPL
   ("C-c b w" . my/restore-debug-windows)))  ; C-c b w — restore windows

;; debug repeat-map
(defvar my/debug-repeat-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "b") #'dape-breakpoint-toggle)
    (define-key map (kbd "n") #'dape-next)
    (define-key map (kbd "i") #'dape-step-in)
    (define-key map (kbd "o") #'dape-step-out)
    (define-key map (kbd "c") #'dape-continue)
    (define-key map (kbd "r") #'dape-restart)
    (define-key map (kbd "q") #'dape-quit)
    (define-key map (kbd "e") #'dape-eval)
    (define-key map (kbd "l") #'dape-repl)
    (define-key map (kbd "w") #'my/restore-debug-windows)
    map))

(dolist (cmd '(dape
               dape-breakpoint-toggle))
  (put cmd 'repeat-map 'my/debug-repeat-map))

;; ----------------------------------------------------------------------------
;; Structural editing (repeat-mode, combobulate, eglot)
;; ----------------------------------------------------------------------------

;; combobulate let's you use context aware editing commands
;; configuration here since it's not tied to configuration for a specific language
(use-package combobulate
  :vc (:url "https://github.com/mickeynp/combobulate" :rev :newest))


;;; provide the feature so (require 'ide-common) works from ide.el
(provide 'ide-common)

;;; ide-common.el ends here

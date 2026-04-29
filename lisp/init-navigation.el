;;; init-navigation.el --- Search, navigation, and contextual actions -*- lexical-binding: t -*-

;;; Commentary:
;; Adds powerful minibuffer-driven navigation and actions:
;;
;;   consult          — high quality search/navigation commands
;;   embark           — context-sensitive actions on minibuffer candidates
;;   embark-consult   — preview integration between consult and embark
;;
;; Works with:
;;   vertico + orderless + marginalia (configured in init-completion.el)

;;; Code:

;; ----------------------------------------------------------------------------
;; Consult — powerful navigation/search commands
;; ----------------------------------------------------------------------------

(use-package consult
  :bind (;; Replace default buffer switching
         ("C-x b" . consult-buffer)

         ;; Replace isearch with a minibuffer search
         ("C-s"   . consult-line)

         ;; Search across project using ripgrep
         ("C-c s" . consult-ripgrep)

         ;; Navigate symbols in current file
         ("C-c o" . consult-outline)

         ;; Diagnostics navigation (Flymake/Eglot)
         ("C-c e" . consult-flymake)

         ;; Recent files
         ("C-c r" . consult-recent-file))

  :config
  ;; Preview results as you move through the list
  (setq consult-preview-key '(:debounce 0.2 any)))

;; ----------------------------------------------------------------------------
;; Embark — contextual actions for minibuffer candidates
;; ----------------------------------------------------------------------------

(use-package embark
  :bind
  (;; Trigger contextual actions
   ("C-." . embark-act)

   ;; Alternative action
   ("C-;" . embark-dwim)

   ;; Show available actions
   ("C-h B" . embark-bindings))

  :init
  ;; Replace prefix-help with Embark
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  ;; Hide the mode line of the Embark action buffer
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect"
                 nil
                 (window-parameters (mode-line-format . none)))))

;; Disable confirmation for kill-buffer via Embark
(with-eval-after-load 'embark
  (setf (alist-get 'kill-buffer embark-pre-action-hooks) nil))

;; ----------------------------------------------------------------------------
;; Embark + Consult integration
;; ----------------------------------------------------------------------------

(use-package embark-consult
  :after (embark consult)
  :hook
  ;; Automatically enable preview in embark collect buffers
  (embark-collect-mode . consult-preview-at-point-mode))

;; ----------------------------
;; Repeat map
;; ----------------------------

(defvar my-basic-repeat-map
  (let ((map (make-sparse-keymap)))
    ;; Movement
    (define-key map (kbd "f") #'forward-char)
    (define-key map (kbd "g") #'forward-word)
    (define-key map (kbd "b") #'backward-char)
    (define-key map (kbd "v") #'backward-word)
    (define-key map (kbd "p") #'previous-line)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "a") #'move-beginning-of-line)
    (define-key map (kbd "e") #'move-end-of-line)

    ;; Editing
    (define-key map (kbd "d") #'delete-char)
    (define-key map (kbd "t") #'transpose-chars)
    (define-key map (kbd "k") #'kill-line)
    (define-key map (kbd "w") #'kill-region)
    (define-key map (kbd "c") #'kill-ring-save)
    (define-key map (kbd "SPC") #'set-mark-command)
    (define-key map (kbd "y") #'yank)
    (define-key map (kbd "/") #'undo)

    (define-key map (kbd "1") #'digit-argument)
    (define-key map (kbd "2") #'digit-argument)
    (define-key map (kbd "3") #'digit-argument)
    (define-key map (kbd "4") #'digit-argument)
    (define-key map (kbd "5") #'digit-argument)
    (define-key map (kbd "6") #'digit-argument)
    (define-key map (kbd "7") #'digit-argument)
    (define-key map (kbd "8") #'digit-argument)
    (define-key map (kbd "9") #'digit-argument)
    map))

(dolist (cmd '(forward-char
               forward-word
               backward-char
               backward-word
               next-line
               previous-line
               kill-line
               kill-ring-save
               set-mark-command
               undo
               move-beginning-of-line
               move-end-of-line
               delete-char
               yank))
  (put cmd 'repeat-map 'my-basic-repeat-map))

;;; Provide feature
(provide 'init-navigation)

;;; init-navigation.el ends here

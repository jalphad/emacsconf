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

;; ;; ----------------------------
;; ;; Repeat map
;; ;; ----------------------------

;; (defvar my-basic-repeat-map
;;   (let ((map (make-sparse-keymap)))
;;     ;; Movement
;;     (define-key map (kbd "f") #'forward-char)
;;     (define-key map (kbd "g") #'forward-word)
;;     (define-key map (kbd "b") #'backward-char)
;;     (define-key map (kbd "v") #'backward-word)
;;     (define-key map (kbd "p") #'previous-line)
;;     (define-key map (kbd "n") #'next-line)
;;     (define-key map (kbd "a") #'move-beginning-of-line)
;;     (define-key map (kbd "e") #'move-end-of-line)

;;     ;; Editing
;;     (define-key map (kbd "d") #'delete-char)
;;     (define-key map (kbd "t") #'transpose-chars)
;;     (define-key map (kbd "k") #'kill-line)
;;     (define-key map (kbd "w") #'kill-region)
;;     (define-key map (kbd "c") #'kill-ring-save)
;;     (define-key map (kbd "SPC") #'set-mark-command)
;;     (define-key map (kbd "y") #'yank)
;;     (define-key map (kbd "/") #'undo)

;;     (define-key map (kbd "1") #'digit-argument)
;;     (define-key map (kbd "2") #'digit-argument)
;;     (define-key map (kbd "3") #'digit-argument)
;;     (define-key map (kbd "4") #'digit-argument)
;;     (define-key map (kbd "5") #'digit-argument)
;;     (define-key map (kbd "6") #'digit-argument)
;;     (define-key map (kbd "7") #'digit-argument)
;;     (define-key map (kbd "8") #'digit-argument)
;;     (define-key map (kbd "9") #'digit-argument)
;;     (define-key map (kbd "0") #'digit-argument)
;;     map))

;; (dolist (cmd '(forward-char
;;                forward-word
;;                backward-char
;;                backward-word
;;                next-line
;;                previous-line
;;                kill-line
;;                kill-ring-save
;;                set-mark-command
;;                undo
;;                move-beginning-of-line
;;                move-end-of-line
;;                delete-char
;;                yank))
;;   (put cmd 'repeat-map 'my-basic-repeat-map))

;; ----------------------------------------------------------------------------
;; Meow - Modal editing
;; ----------------------------------------------------------------------------

(defun meow-setup ()
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
  (meow-motion-define-key
   '("j" . meow-next)
   '("k" . meow-prev)
   '("<escape>" . ignore))
  (meow-leader-define-key
   ;; Use SPC (0-9) for digit arguments.
   '("1" . meow-digit-argument)
   '("2" . meow-digit-argument)
   '("3" . meow-digit-argument)
   '("4" . meow-digit-argument)
   '("5" . meow-digit-argument)
   '("6" . meow-digit-argument)
   '("7" . meow-digit-argument)
   '("8" . meow-digit-argument)
   '("9" . meow-digit-argument)
   '("0" . meow-digit-argument)
   '("/" . meow-keypad-describe-key)
   '("?" . meow-cheatsheet))
  (meow-normal-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("a" . meow-append)
   '("A" . meow-open-below)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   '("d" . meow-delete)
   '("D" . meow-backward-delete)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("g" . meow-cancel-selection)
   '("G" . meow-grab)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("I" . meow-open-above)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   '("m" . meow-join)
   '("n" . meow-search)
   '("o" . meow-block)
   '("O" . meow-to-block)
   '("p" . meow-yank)
   '("q" . meow-quit)
   '("Q" . meow-goto-line)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("s" . meow-kill)
   '("t" . meow-till)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("v" . meow-visit)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("x" . meow-line)
   '("X" . meow-goto-line)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("'" . repeat)
   '("<escape>" . ignore)))

(require 'meow)
(meow-setup)
(meow-global-mode 1)

;;; Provide feature
(provide 'init-navigation)

;;; init-navigation.el ends here

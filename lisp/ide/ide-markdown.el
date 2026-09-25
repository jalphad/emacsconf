;;; ide-markdown.el --- Markdown editing and Mermaid preview -*- lexical-binding: t -*-

;;; Commentary:
;; Markdown editing is provided by markdown-mode.  A live browser preview is
;; provided by mpls, which renders fenced Mermaid blocks such as:
;;
;;   ```mermaid
;;   flowchart LR
;;     A --> B
;;   ```
;;
;; External tool required on PATH for previews:
;;   mpls  -- https://github.com/mhersson/mpls

;;; Code:

(defvar eglot-server-programs)

(declare-function eglot-current-server "eglot")
(declare-function eglot-ensure "eglot")
(declare-function eglot-execute "eglot")

(defun my/markdown-mpls-available-p ()
  "Return non-nil when the mpls executable is available on PATH."
  (executable-find "mpls"))

(defun my/markdown-maybe-start-eglot ()
  "Start the mpls preview server when it is installed."
  (when (my/markdown-mpls-available-p)
    (eglot-ensure)))

(defun my/markdown-preview ()
  "Open a live preview of the current Markdown buffer.

Fenced `mermaid' blocks are rendered as diagrams by mpls."
  (interactive)
  (unless (derived-mode-p 'markdown-mode)
    (user-error "This command is only available in Markdown buffers"))
  (unless (my/markdown-mpls-available-p)
    (user-error "Install mpls and make sure it is available on PATH"))
  (eglot-ensure)
  (let ((server (eglot-current-server)))
    (unless server
      (user-error "mpls did not start successfully"))
    (eglot-execute server '(:command "open-preview"))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((markdown-mode gfm-mode)
                 . ("mpls" "--no-auto"))))

(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :hook ((markdown-mode . my/markdown-maybe-start-eglot)
         (gfm-mode . my/markdown-maybe-start-eglot))
  :bind (:map markdown-mode-map
              ("C-c C-p" . my/markdown-preview)))

(provide 'ide-markdown)

;;; ide-markdown.el ends here

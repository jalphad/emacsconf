;;; ide-nix.el --- Nix language configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Basic Nix IDE support built on:
;;   nix-mode  — major mode and syntax highlighting for Nix expressions
;;   eglot     — LSP client connecting to nixd
;;
;; External tool required on PATH:
;;   nixd      — Nix language server

;;; Code:

(defvar eglot-server-programs)

(declare-function cape-capf-super "cape")
(declare-function eglot-completion-at-point "eglot")
(declare-function eglot-ensure "eglot")
(declare-function eglot-managed-p "eglot")
(declare-function yas-minor-mode "yasnippet")
(declare-function yasnippet-capf "yasnippet-capf")

(defun my/nix-nixd-available-p ()
  "Return non-nil when nixd is available on PATH."
  (executable-find "nixd"))

(defun my/nix-maybe-start-eglot ()
  "Start Eglot for Nix when nixd is installed."
  (if (my/nix-nixd-available-p)
      (eglot-ensure)
    (message "Install nixd for Nix completion, diagnostics, xref, and code actions")))

(defun my/nix-eglot-completion-at-point ()
  "Return Eglot completions when Eglot manages the current buffer."
  (when (and (fboundp 'eglot-managed-p)
             (eglot-managed-p))
    (eglot-completion-at-point)))

(defun my/nix-mode-setup ()
  "Set up IDE features for Nix buffers."
  (yas-minor-mode)
  (my/nix-maybe-start-eglot)
  (setq-local completion-at-point-functions
              (list (cape-capf-super
                     #'my/nix-eglot-completion-at-point
                     #'yasnippet-capf))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nixd"))))

(use-package nix-mode
  :mode ("\\.nix\\'" . nix-mode)
  :hook (nix-mode . my/nix-mode-setup))

(provide 'ide-nix)

;;; ide-nix.el ends here

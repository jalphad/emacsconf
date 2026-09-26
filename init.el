;;; init.el --- Personal Emacs configuration -*- lexical-binding: t -*-

;; Add lisp/ to load path
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp/ide/" user-emacs-directory))

;; Add custom themes load path
(add-to-list 'custom-theme-load-path (expand-file-name "themes" user-emacs-directory))

;; Initialize package.el and use-package.
(require 'init-packages)

;; Load modules
(require 'init-defaults)
(require 'init-completion)
(require 'init-ui)
(require 'init-ide)
(require 'init-navigation)

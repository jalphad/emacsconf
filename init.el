;; Add lisp/ to load path
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp/ide/" user-emacs-directory))

;; Bootstrap package manager (e.g. straight.el or elpaca)
(require 'init-packages)

;; Load modules
(require 'init-defaults)
(require 'init-completion)
(require 'init-ui)
(require 'init-ide)
(require 'init-navigation)

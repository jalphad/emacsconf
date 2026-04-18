;;; init-packages.el --- Package manager configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Sets up package.el with MELPA and use-package.
;; All other modules should use `use-package' to declare their dependencies.

;;; Code:

;; ----------------------------------------------------------------------------
;; Package archives
;; ----------------------------------------------------------------------------

(require 'package)

;; Add MELPA to the list of archives. GNU ELPA is included by default.
;; MELPA Stable (melpa-stable.milkbox.net) is an alternative if you prefer
;; only release-tagged packages, but plain MELPA has much broader coverage.
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

;; Initialise the package system. This reads the archive contents and makes
;; installed packages available. On first run the archive index is empty until
;; you call `package-refresh-contents'.
(package-initialize)

;; ----------------------------------------------------------------------------
;; Refresh archive index when stale
;; ----------------------------------------------------------------------------

;; Fetch the package index from the archives if we don't have it yet.
;; This happens on a fresh install; subsequent startups skip the network call.
(unless package-archive-contents
  (package-refresh-contents))

;; ----------------------------------------------------------------------------
;; use-package bootstrap
;; ----------------------------------------------------------------------------

;; use-package is built in from Emacs 29 onwards. Install it from MELPA for
;; older versions so the rest of the config can rely on it unconditionally.
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)

;; Always ensure packages declared with use-package are installed if missing.
;; This means you don't need to add `:ensure t` to every use-package block.
(setq use-package-always-ensure t)

;; Uncomment to get a breakdown of load times per package on startup.
;; Useful when diagnosing a slow init.
;; (setq use-package-verbose t)

;;; provide the feature so (require 'init-packages) works from init.el
(provide 'init-packages)

;;; init-packages.el ends here

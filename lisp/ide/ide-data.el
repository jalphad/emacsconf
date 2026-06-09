;;; ide-data.el --- JSON and YAML IDE configuration -*- lexical-binding: t -*-

;;; Commentary:
;; JSON/YAML support built on:
;;   json-ts-mode          — tree-sitter JSON mode, built in to Emacs 30
;;   yaml-ts-mode          — tree-sitter YAML mode, built in to Emacs 30
;;   eglot                 — LSP client for schema completion, validation, and $ref
;;   apheleia              — optional async formatting via prettier
;;
;; External tools recommended on your PATH:
;;   vscode-json-language-server  — npm install -g vscode-langservers-extracted
;;   yaml-language-server         — npm install -g yaml-language-server
;;   prettier                     — npm install -g prettier

;;; Code:

(require 'treesit)

(defvar eglot-server-programs)
(defvar apheleia-formatters)
(defvar apheleia-mode-alist)

(declare-function eglot-alternatives "eglot")
(declare-function eglot-completion-at-point "eglot")
(declare-function eglot-ensure "eglot")
(declare-function my/gopls-workspace-configuration "ide-common")
(declare-function cape-capf-super "cape")
(declare-function cape-file "cape")
(declare-function yas-minor-mode "yasnippet")
(declare-function yasnippet-capf "yasnippet")
(declare-function yaml-mode "yaml-mode")

(defconst my/data-openapi-schema-url
  "https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/schemas/v3.1/schema.json"
  "JSON Schema URL used for OpenAPI 3.1 JSON and YAML documents.")

(defconst my/data-kubernetes-schema-url
  "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone-strict/all.json"
  "Strict Kubernetes JSON Schema URL used for Kubernetes manifests.")

(defconst my/data-github-actions-schema-url
  "https://json.schemastore.org/github-workflow.json"
  "JSON Schema URL used for GitHub Actions workflow files.")

(defconst my/data-docker-compose-schema-url
  "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"
  "JSON Schema URL used for Docker Compose files.")

(defconst my/data-openapi-file-patterns
  ["openapi.json"
   "openapi.yaml"
   "openapi.yml"
   "openapi.*.json"
   "openapi.*.yaml"
   "openapi.*.yml"
   "*.openapi.json"
   "*.openapi.yaml"
   "*.openapi.yml"]
  "File patterns that should use the OpenAPI schema.")

(defconst my/data-kubernetes-file-patterns
  ["k8s/**/*.yaml"
   "k8s/**/*.yml"
   "kubernetes/**/*.yaml"
   "kubernetes/**/*.yml"
   "manifests/**/*.yaml"
   "manifests/**/*.yml"
   "deploy/**/*.yaml"
   "deploy/**/*.yml"
   "deployments/**/*.yaml"
   "deployments/**/*.yml"]
  "File patterns that should use the Kubernetes schema.")

(defconst my/data-github-actions-file-patterns
  [".github/workflows/*.yaml"
   ".github/workflows/*.yml"]
  "File patterns that should use the GitHub Actions workflow schema.")

(defconst my/data-docker-compose-file-patterns
  ["compose.yaml"
   "compose.yml"
   "docker-compose.yaml"
   "docker-compose.yml"
   "docker-compose.*.yaml"
   "docker-compose.*.yml"]
  "File patterns that should use the Docker Compose schema.")

(defun my/data-workspace-configuration ()
  "Return LSP workspace settings for JSON and YAML servers."
  (let ((yaml-schemas (make-hash-table :test #'equal)))
    (puthash my/data-openapi-schema-url my/data-openapi-file-patterns yaml-schemas)
    (puthash my/data-kubernetes-schema-url my/data-kubernetes-file-patterns yaml-schemas)
    (puthash my/data-github-actions-schema-url my/data-github-actions-file-patterns yaml-schemas)
    (puthash my/data-docker-compose-schema-url my/data-docker-compose-file-patterns yaml-schemas)
    `((:json . (:validate (:enable t)
                :schemaStore (:enable t)
                :schemas [(:name "OpenAPI 3.1"
                           :url ,my/data-openapi-schema-url
                           :fileMatch ,my/data-openapi-file-patterns)]))
      (:yaml . (:validate t
                :hover t
                :completion t
                :format (:enable nil)
                :schemaStore (:enable t)
                :schemas ,yaml-schemas)))))

(defun my/data--server-executable ()
  "Return the expected language-server executable for the current data mode."
  (pcase major-mode
    ((or 'json-ts-mode 'js-json-mode)
     (or (executable-find "vscode-json-language-server")
         (executable-find "vscode-json-languageserver")))
    ((or 'yaml-ts-mode 'yaml-mode)
     (executable-find "yaml-language-server"))))

(defun my/data-maybe-start-eglot ()
  "Start Eglot when the JSON/YAML language server is installed."
  (if (my/data--server-executable)
      (eglot-ensure)
    (message "Install vscode-langservers-extracted or yaml-language-server for schema completion and $ref navigation")))

(defun my/data-mode-setup ()
  "Shared setup for JSON and YAML buffers."
  (yas-minor-mode)
  (my/data-maybe-start-eglot)
  (setq-local completion-at-point-functions
              (list (cape-capf-super
                     #'eglot-completion-at-point
                     #'yasnippet-capf
                     #'cape-file))))

(defun my/data-treesit-ready-p (language)
  "Return non-nil when tree-sitter LANGUAGE can be used."
  (treesit-ready-p language t))

(defun my/data-json-mode ()
  "Use tree-sitter JSON mode when available, otherwise use `js-json-mode'."
  (interactive)
  (if (my/data-treesit-ready-p 'json)
      (json-ts-mode)
    (js-json-mode)))

(defun my/data-yaml-mode ()
  "Use tree-sitter YAML mode when available, otherwise use `yaml-mode'."
  (interactive)
  (if (my/data-treesit-ready-p 'yaml)
      (yaml-ts-mode)
    (yaml-mode)))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(json-ts-mode . ,(eglot-alternatives
                                  '(("vscode-json-language-server" "--stdio")
                                    ("vscode-json-languageserver" "--stdio")))))
  (add-to-list 'eglot-server-programs
               `(js-json-mode . ,(eglot-alternatives
                                  '(("vscode-json-language-server" "--stdio")
                                    ("vscode-json-languageserver" "--stdio")))))
  (add-to-list 'eglot-server-programs
               '(yaml-ts-mode . ("yaml-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(yaml-mode . ("yaml-language-server" "--stdio")))
  (setq-default eglot-workspace-configuration
                (append (my/gopls-workspace-configuration)
                        (my/data-workspace-configuration))))

;; ----------------------------------------------------------------------------
;; json-ts-mode — tree-sitter JSON editing
;; ----------------------------------------------------------------------------

(use-package json-ts-mode
  :ensure nil
  :mode ("\\.json\\'" . my/data-json-mode)
  :hook (json-ts-mode . my/data-mode-setup))

(use-package js
  :ensure nil
  :hook (js-json-mode . my/data-mode-setup))

;; ----------------------------------------------------------------------------
;; yaml-ts-mode — tree-sitter YAML editing
;; ----------------------------------------------------------------------------

(use-package yaml-ts-mode
  :ensure nil
  :hook (yaml-ts-mode . my/data-mode-setup))

(use-package yaml-mode
  :ensure t
  :commands yaml-mode
  :mode ("\\.ya?ml\\'" . my/data-yaml-mode)
  :hook (yaml-mode . my/data-mode-setup))

;; ----------------------------------------------------------------------------
;; Formatting
;; ----------------------------------------------------------------------------

(with-eval-after-load 'apheleia
  (setf (alist-get 'prettier-json apheleia-formatters)
        '("prettier" "--parser" "json"))
  (setf (alist-get 'prettier-yaml apheleia-formatters)
        '("prettier" "--parser" "yaml"))
  (setf (alist-get 'json-ts-mode apheleia-mode-alist) 'prettier-json)
  (setf (alist-get 'js-json-mode apheleia-mode-alist) 'prettier-json)
  (setf (alist-get 'yaml-ts-mode apheleia-mode-alist) 'prettier-yaml)
  (setf (alist-get 'yaml-mode apheleia-mode-alist) 'prettier-yaml))

(provide 'ide-data)

;;; ide-data.el ends here

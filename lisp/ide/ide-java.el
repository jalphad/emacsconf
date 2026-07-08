;;; ide-java.el --- Java language configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Java IDE setup built on:
;;   java-ts-mode   — tree-sitter based major mode, built in to Emacs 29+
;;   eglot          — LSP client connecting to Eclipse JDT Language Server
;;   dape           — DAP client using the JDTLS Java Debug Server plugin
;;   apheleia       — optional formatting via google-java-format
;;
;; External tools recommended on your PATH:
;;   java, javac    — JDK 17+ recommended for jdtls
;;   jdtls          — Eclipse JDT Language Server
;;   mvn or ./mvnw  — Maven test/build support
;;   gradle or ./gradlew — Gradle test/build support
;;   google-java-format — optional formatter
;;
;; Debugging requires the Microsoft Java Debug Server plugin to be loaded by
;; jdtls. Set `my/java-debug-plugin-jars' or JAVA_DEBUG_PLUGIN_JARS to the jar.

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'treesit)

(defvar eglot-server-programs)
(defvar apheleia-formatters)
(defvar apheleia-mode-alist)
(defvar dape-configs)

(declare-function cape-capf-super "cape")
(declare-function combobulate-mode "combobulate")
(declare-function dape "dape")
(declare-function eglot-completion-at-point "eglot")
(declare-function eglot-current-server "eglot")
(declare-function eglot-ensure "eglot")
(declare-function eglot-managed-p "eglot")
(declare-function eglot-execute-command "eglot")
(declare-function envrc-reload "envrc")
(declare-function projectile-register-project-type "projectile")
(declare-function yas-minor-mode "yasnippet")
(declare-function yasnippet-capf "yasnippet")

(defcustom my/java-debug-plugin-jars nil
  "List of Java Debug Server plugin jars passed to jdtls.
When nil, `my/java-debug-plugin-jars' also checks the
JAVA_DEBUG_PLUGIN_JARS environment variable. Use colon-separated
paths in the environment variable."
  :type '(repeat file)
  :group 'my/java)

(defun my/java-debug-plugin-jars ()
  "Return configured Java Debug Server plugin jar paths."
  (or my/java-debug-plugin-jars
      (when-let ((env (getenv "JAVA_DEBUG_PLUGIN_JARS")))
        (split-string env path-separator t))))

(defun my/java-treesit-ready-p ()
  "Return non-nil when the Java tree-sitter grammar can be used."
  (treesit-ready-p 'java t))

(defun my/java-mode ()
  "Use tree-sitter Java mode when available, otherwise use `java-mode'."
  (interactive)
  (if (my/java-treesit-ready-p)
      (java-ts-mode)
    (java-mode)))

(defun my/java-jdtls-command ()
  "Return the jdtls command for Eglot, including debug bundles when configured."
  (let ((bundles (vconcat (my/java-debug-plugin-jars)))
        (jdtls (or (getenv "JDTLS_PATH") "jdtls")))
    (if (> (length bundles) 0)
        `(,jdtls :initializationOptions (:bundles ,bundles))
      `(,jdtls))))

(defun my/java-jdtls-available-p ()
  "Return non-nil when jdtls is available in PATH or via JDTLS_PATH."
  (let ((jdtls-path (getenv "JDTLS_PATH")))
    (or (executable-find "jdtls")
        (and jdtls-path (file-executable-p jdtls-path)))))

(defun my/java-reload-direnv ()
  "Reload direnv/envrc for the current buffer when available."
  (when (fboundp 'envrc-reload)
    (ignore-errors
      (envrc-reload))))

(defun my/java-project-root ()
  "Return the Java project root for the current buffer."
  (or (locate-dominating-file default-directory "mvnw")
      (locate-dominating-file default-directory "pom.xml")
      (locate-dominating-file default-directory "gradlew")
      (locate-dominating-file default-directory "settings.gradle")
      (locate-dominating-file default-directory "settings.gradle.kts")
      (locate-dominating-file default-directory "build.gradle")
      (locate-dominating-file default-directory "build.gradle.kts")
      (when-let ((project (project-current nil)))
        (project-root project))
      default-directory))

(defun my/java--root-file (file)
  "Return FILE expanded relative to the Java project root."
  (expand-file-name file (my/java-project-root)))

(defun my/java--executable (wrapper command)
  "Return WRAPPER in project root when present, otherwise COMMAND."
  (let ((wrapper-path (my/java--root-file wrapper)))
    (if (file-executable-p wrapper-path)
        (concat "./" wrapper)
      command)))

(defun my/java-build-tool ()
  "Return the detected Java build tool as `maven', `gradle', or nil."
  (cond
   ((or (file-exists-p (my/java--root-file "mvnw"))
        (file-exists-p (my/java--root-file "pom.xml")))
    'maven)
   ((or (file-exists-p (my/java--root-file "gradlew"))
        (file-exists-p (my/java--root-file "settings.gradle"))
        (file-exists-p (my/java--root-file "settings.gradle.kts"))
        (file-exists-p (my/java--root-file "build.gradle"))
        (file-exists-p (my/java--root-file "build.gradle.kts")))
    'gradle)))

(defun my/java-package-name ()
  "Return the package declared in the current Java buffer, or nil."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^[ \t]*package[ \t]+\\([A-Za-z0-9_.]+\\)[ \t]*;" nil t)
      (match-string-no-properties 1))))

(defun my/java-class-name ()
  "Return the current Java class name, preferring the file name."
  (or (when buffer-file-name
        (file-name-base buffer-file-name))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward
               "^[ \t]*\\(?:public[ \t]+\\)?\\(?:class\\|interface\\|enum\\|record\\)[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)"
               nil t)
          (match-string-no-properties 1)))))

(defun my/java-qualified-class-name ()
  "Return the fully qualified Java class name for the current buffer."
  (let ((package (my/java-package-name))
        (class (my/java-class-name)))
    (when class
      (if package
          (concat package "." class)
        class))))

(defun my/java-test-method-at-point ()
  "Return the nearest Java test method name around point, or nil."
  (save-excursion
    (let ((limit (save-excursion
                   (or (re-search-backward "^[ \t]*\\(?:public[ \t]+\\)?\\(?:class\\|interface\\|enum\\|record\\)\\b" nil t)
                       (point-min))))
          method)
      (while (and (not method)
                  (re-search-backward
                   "^[ \t]*\\(?:public\\|protected\\|private\\|static\\|final\\|synchronized\\|abstract\\|native\\|strictfp\\|default\\|[ \t]\\)*\\(?:[A-Za-z_$][A-Za-z0-9_.$<>?, \t\\[\\]]+[ \t]+\\)+\\([A-Za-z_$][A-Za-z0-9_$]*\\)[ \t]*(\\([^;{}]*\\))[ \t\n\r]*\\(?:throws[^{]+\\)?{"
                   limit t))
        (let ((candidate (match-string-no-properties 1))
              (start (match-beginning 0)))
          (save-excursion
            (goto-char start)
            (when (re-search-backward
                   "^[ \t]*@\\(?:org\\.junit\\.jupiter\\.api\\.\\|org\\.junit\\.\\)?\\(?:Test\\|ParameterizedTest\\|RepeatedTest\\|TestFactory\\|TestTemplate\\)\\b"
                   (max limit (- start 600)) t)
              (setq method candidate)))))
      method)))

(defun my/java--test-selector ()
  "Return a cons of fully qualified class name and optional test method."
  (let ((class (my/java-qualified-class-name)))
    (unless class
      (user-error "Could not determine Java class name"))
    (cons class (my/java-test-method-at-point))))

(defun my/java--test-command (&optional debug)
  "Return a command that runs the Java test at point.
When DEBUG is non-nil, start the test JVM suspended on port 5005."
  (pcase-let* ((`(,class . ,method) (my/java--test-selector))
               (selector (if method (concat class "." method) class))
               (root (my/java-project-root)))
    (pcase (my/java-build-tool)
      ('maven
       (let* ((mvn (my/java--executable "mvnw" "mvn"))
              (test (if method
                        (concat (my/java-class-name) "#" method)
                      (my/java-class-name)))
              (debug-prefix (when debug
                              "MAVEN_OPTS='-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:5005' ")))
         (cons root
               (concat debug-prefix mvn " -Dtest="
                       (shell-quote-argument test)
                       " test"))))
      ('gradle
       (let ((gradle (my/java--executable "gradlew" "gradle")))
         (cons root
               (concat gradle " test"
                       (when debug " --debug-jvm")
                       " --tests "
                       (shell-quote-argument selector)))))
      (_
       (user-error "Could not detect Maven or Gradle project")))))

(defun my/java-run-test-at-point ()
  "Run the Java test method or class at point with Maven or Gradle."
  (interactive)
  (pcase-let ((`(,root . ,command) (my/java--test-command)))
    (let ((default-directory root))
      (message "Running: %s" command)
      (compile command))))

(defun my/java-run-test-file ()
  "Run all Java tests in the current file."
  (interactive)
  (let ((method nil))
    (cl-letf (((symbol-function 'my/java-test-method-at-point)
               (lambda () method)))
      (pcase-let ((`(,root . ,command) (my/java--test-command)))
        (let ((default-directory root))
          (message "Running: %s" command)
          (compile command))))))

(defun my/java-run-test-project ()
  "Run the Java project's test suite with Maven or Gradle."
  (interactive)
  (let ((default-directory (my/java-project-root)))
    (pcase (my/java-build-tool)
      ('maven (compile (concat (my/java--executable "mvnw" "mvn") " test")))
      ('gradle (compile (concat (my/java--executable "gradlew" "gradle") " test")))
      (_ (user-error "Could not detect Maven or Gradle project")))))

(defun my/java-debug-test-at-point ()
  "Debug the Java test method or class at point.
This starts the build tool in debug mode and attaches Dape to port 5005."
  (interactive)
  (pcase-let ((`(,root . ,command) (my/java--test-command t)))
    (let ((default-directory root))
      (message "Debugging: %s" command)
      (compile command)
      (run-at-time
       1 nil
       (lambda ()
         (dape `(jdtls-attach
                 modes (java-ts-mode java-mode)
                 :request "attach"
                 :type "java"
                 :hostName "localhost"
                 :port 5005)))))))

(defun my/java-maybe-start-eglot ()
  "Start Eglot for Java when jdtls is installed."
  (my/java-reload-direnv)
  (if (my/java-jdtls-available-p)
      (eglot-ensure)
    (message "Install jdtls for Java completion, diagnostics, xref, and code actions")))

(defun my/java-eglot-completion-at-point ()
  "Return Eglot completions only when Eglot manages the current buffer."
  (when (and (fboundp 'eglot-managed-p)
             (eglot-managed-p))
    (eglot-completion-at-point)))

(defun my/java-ensure-navigation-backend ()
  "Ensure Java navigation is backed by Eglot before invoking xref."
  (unless (my/java-jdtls-available-p)
    (user-error "jdtls is not installed or not on PATH"))
  (unless (eglot-managed-p)
    (user-error "Eglot is not managing this Java buffer; run M-x eglot or reopen the file after installing jdtls")))

(defun my/java-goto-definition ()
  "Jump to the definition at point using Eglot/xref."
  (interactive)
  (my/java-ensure-navigation-backend)
  (call-interactively #'xref-find-definitions))

(defun my/java-goto-references ()
  "Find references to the symbol at point using Eglot/xref."
  (interactive)
  (my/java-ensure-navigation-backend)
  (call-interactively #'xref-find-references))

(defun my/java-pop-back ()
  "Return to the previous xref location."
  (interactive)
  (call-interactively #'xref-go-back))

(defun my/java-mode-setup ()
  "Shared setup for Java buffers."
  (yas-minor-mode)
  (my/java-maybe-start-eglot)
  (when (fboundp 'combobulate-mode)
    (combobulate-mode))
  (setq-local completion-at-point-functions
              (list (cape-capf-super
                     #'my/java-eglot-completion-at-point
                     #'yasnippet-capf))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `((java-mode java-ts-mode) . ,(my/java-jdtls-command))))

(with-eval-after-load 'dape
  (add-to-list 'dape-configs
               `(jdtls
                 modes (java-ts-mode java-mode)
                 fn (lambda (config)
                      (plist-put
                       config
                       :port
                       (eglot-execute-command
                        (eglot-current-server)
                        "vscode.java.startDebugSession"
                        nil)))
                 :request "launch"
                 :type "java"
                 :mainClass nil
                 :projectName nil))
  (add-to-list 'dape-configs
               `(jdtls-attach
                 modes (java-ts-mode java-mode)
                 fn (lambda (config)
                      (plist-put
                       config
                       :port
                       (or (plist-get config :port)
                           (eglot-execute-command
                            (eglot-current-server)
                            "vscode.java.startDebugSession"
                            nil))))
                 :request "attach"
                 :type "java"
                 :hostName "localhost"
                 :port 5005)))

(with-eval-after-load 'apheleia
  (setf (alist-get 'google-java-format apheleia-formatters)
        '("google-java-format" "-"))
  (setf (alist-get 'java-ts-mode apheleia-mode-alist) 'google-java-format)
  (setf (alist-get 'java-mode apheleia-mode-alist) 'google-java-format))

(use-package java-ts-mode
  :ensure nil
  :mode ("\\.java\\'" . my/java-mode)
  :hook (java-ts-mode . my/java-mode-setup)
  :bind (:map java-ts-mode-map
              ("C-c t t" . my/java-run-test-at-point)
              ("C-c t d" . my/java-debug-test-at-point)
              ("C-c t f" . my/java-run-test-file)
              ("C-c t p" . my/java-run-test-project)
              ("M-." . my/java-goto-definition)
              ("M-," . my/java-pop-back)
              ("M-?" . my/java-goto-references))
  :config
  (when (my/java-treesit-ready-p)
    (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode))))

(use-package cc-mode
  :ensure nil
  :hook (java-mode . my/java-mode-setup)
  :bind (:map java-mode-map
              ("C-c t t" . my/java-run-test-at-point)
              ("C-c t d" . my/java-debug-test-at-point)
              ("C-c t f" . my/java-run-test-file)
              ("C-c t p" . my/java-run-test-project)
              ("M-." . my/java-goto-definition)
              ("M-," . my/java-pop-back)
              ("M-?" . my/java-goto-references)))

(with-eval-after-load 'projectile
  (projectile-register-project-type
   'maven '("pom.xml")
   :project-file "pom.xml"
   :compile "mvn compile"
   :test "mvn test")
  (projectile-register-project-type
   'gradle '("build.gradle" "build.gradle.kts" "settings.gradle" "settings.gradle.kts")
   :compile "gradle classes"
   :test "gradle test"))

(provide 'ide-java)

;;; ide-java.el ends here

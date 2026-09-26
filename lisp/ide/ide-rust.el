;;; ide-rust.el --- Rust language configuration -*- lexical-binding: t -*-

;;; Commentary:
;; IntelliJ-like Rust support built on:
;;   rust-ts-mode / rust-mode — tree-sitter mode with a portable fallback
;;   eglot                   — Rust Analyzer LSP integration
;;   apheleia                — asynchronous rustfmt/Taplo formatting
;;   dape + lldb-dap         — Cargo-aware debugging
;;   coverlay                — inline LCOV coverage
;;
;; External tools used when available:
;;   cargo, rustc, rustfmt, rust-analyzer, lldb-dap, taplo, cargo-llvm-cov
;;
;; Combobulate is deliberately not enabled: the installed Combobulate version
;; does not include Rust language support.

;;; Code:

(require 'cl-lib)
(require 'compile)
(require 'json)
(require 'project)
(require 'seq)
(require 'subr-x)

(defvar apheleia-formatters)
(defvar apheleia-mode-alist)
(defvar coverlay:base-path)
(defvar dape-configs)
(defvar eglot-server-programs)
(defvar eglot-workspace-configuration)

(declare-function cape-capf-super "cape")
(declare-function coverlay-load-file "coverlay")
(declare-function dape "dape")
(declare-function dape-ensure-command "dape")
(declare-function eglot--TextDocumentPositionParams "eglot")
(declare-function eglot--current-server-or-lose "eglot")
(declare-function eglot--request "eglot")
(declare-function eglot-completion-at-point "eglot")
(declare-function eglot-current-server "eglot")
(declare-function eglot-ensure "eglot")
(declare-function eglot-find-implementation "eglot")
(declare-function eglot-find-typeDefinition "eglot")
(declare-function eglot-managed-p "eglot")
(declare-function eglot-range-region "eglot")
(declare-function eglot-show-call-hierarchy "eglot")
(declare-function eglot-uri-to-path "eglot")
(declare-function envrc-mode "envrc")
(declare-function jsonrpc-request "jsonrpc")
(declare-function yas-minor-mode "yasnippet")
(declare-function yasnippet-capf "yasnippet-capf")

(defgroup my/rust nil
  "Rust IDE configuration."
  :group 'tools)

(defcustom my/rust-lldb-dap-command
  (or (getenv "LLDB_DAP_PATH") "lldb-dap")
  "LLDB DAP adapter executable used by Dape.
Set LLDB_DAP_PATH or customize this variable when the adapter is not on PATH."
  :type 'file
  :group 'my/rust)

(defcustom my/rust-coverage-file
  (file-name-concat "target" "llvm-cov" "lcov.info")
  "Coverage file path relative to the Cargo workspace root."
  :type 'string
  :group 'my/rust)

(defun my/rust-analyzer-settings ()
  "Return Rust Analyzer settings used for initialization and the workspace."
  '(:check (:command "clippy"
            :workspace t
            :allTargets t)
    :cargo (:allTargets t
            :buildScripts (:enable t))
    :procMacro (:enable t
                :attributes (:enable t))
    :completion (:autoimport (:enable t)
                 :callable (:snippets "fill_arguments")
                 :postfix (:enable t))
    :inlayHints (:typeHints (:enable t)
                 :parameterHints (:enable t)
                 :chainingHints (:enable t)
                 :closingBraceHints (:enable t
                                     :minLines 25))
    :semanticHighlighting (:nonStandardTokens t)
    :runnables (:extraTestBinaryArgs ["--nocapture"])))

(defun my/rust-workspace-configuration ()
  "Return the Rust Analyzer section for `eglot-workspace-configuration'."
  `(:rust-analyzer ,(my/rust-analyzer-settings)))

(defun my/rust-merge-workspace-configuration (configuration)
  "Add Rust Analyzer settings to Eglot CONFIGURATION without losing sections."
  (plist-put (copy-tree configuration)
             :rust-analyzer
             (my/rust-analyzer-settings)))

(defun my/rust-project-root ()
  "Return the nearest Cargo or Emacs project root."
  (file-name-as-directory
   (or (locate-dominating-file default-directory "Cargo.toml")
       (when-let* ((project (project-current nil)))
         (project-root project))
       default-directory)))

(defun my/rust--server-available-p ()
  "Return non-nil when Rust Analyzer is available."
  (executable-find "rust-analyzer"))

(defun my/rust-load-project-environment ()
  "Import the current buffer's direnv environment when available.
This makes tools supplied by a Nix flake visible before Eglot checks PATH."
  (when (and (fboundp 'envrc-mode)
             (executable-find "direnv"))
    (envrc-mode 1)))

(defun my/rust-maybe-start-eglot ()
  "Start Eglot for Rust when Rust Analyzer is installed."
  (if (my/rust--server-available-p)
      (eglot-ensure)
    (message (concat "rust-analyzer is not on this buffer's PATH; "
                     "for a Nix flake, add an allowed .envrc containing `use flake'"))))

(defun my/rust-eglot-completion-at-point ()
  "Return Rust Analyzer completions when Eglot manages this buffer."
  (when (and (fboundp 'eglot-managed-p)
             (eglot-managed-p))
    (eglot-completion-at-point)))

(defun my/rust-mode-setup ()
  "Set up completion and language tooling in a Rust source buffer."
  (yas-minor-mode)
  (my/rust-load-project-environment)
  (setq-local eglot-workspace-configuration
              (my/rust-merge-workspace-configuration
               (default-value 'eglot-workspace-configuration)))
  (my/rust-maybe-start-eglot)
  (setq-local completion-at-point-functions
              (list (cape-capf-super
                     #'my/rust-eglot-completion-at-point
                     #'yasnippet-capf))))

(defun my/rust-toml-setup ()
  "Start Taplo in TOML buffers when it is installed."
  (yas-minor-mode)
  (my/rust-load-project-environment)
  (when (executable-find "taplo")
    (eglot-ensure))
  (setq-local completion-at-point-functions
              (list (cape-capf-super
                     #'my/rust-eglot-completion-at-point
                     #'yasnippet-capf))))

;; ---------------------------------------------------------------------------
;; Rust Analyzer extension requests
;; ---------------------------------------------------------------------------

(defun my/rust--position-params ()
  "Return LSP text-document position parameters for the current point."
  (eglot--TextDocumentPositionParams))

(defun my/rust--request (method params)
  "Send Rust Analyzer request METHOD with PARAMS through Eglot."
  (unless (and (fboundp 'eglot-managed-p) (eglot-managed-p))
    (user-error "Rust Analyzer is not managing this buffer"))
  (eglot--request (eglot--current-server-or-lose) method params))

(defun my/rust--runnables (&optional whole-file)
  "Return Rust Analyzer runnables at point.
When WHOLE-FILE is non-nil, request runnables for the entire file."
  (let* ((position-params (my/rust--position-params))
         (params (if whole-file
                     (list :textDocument
                           (plist-get position-params :textDocument))
                   position-params))
         (response (my/rust--request :experimental/runnables params)))
    (append response nil)))

(defun my/rust--runnable-args (runnable)
  "Return the protocol-specific argument object from RUNNABLE."
  (plist-get runnable :args))

(defun my/rust--runnable-cargo-p (runnable)
  "Return non-nil when RUNNABLE describes a Cargo command."
  (equal (plist-get runnable :kind) "cargo"))

(defun my/rust--runnable-shell-p (runnable)
  "Return non-nil when RUNNABLE describes a shell command."
  (equal (plist-get runnable :kind) "shell"))

(defun my/rust--runnable-cargo-args (runnable)
  "Return RUNNABLE's Cargo arguments as a list."
  (append (plist-get (my/rust--runnable-args runnable) :cargoArgs) nil))

(defun my/rust--runnable-executable-args (runnable)
  "Return RUNNABLE's executable arguments as a list."
  (append (plist-get (my/rust--runnable-args runnable) :executableArgs) nil))

(defun my/rust--runnable-command-p (runnable command)
  "Return non-nil when Cargo RUNNABLE invokes COMMAND."
  (and (my/rust--runnable-cargo-p runnable)
       (member command (my/rust--runnable-cargo-args runnable))))

(defun my/rust--filter-runnables (runnables command)
  "Return RUNNABLES whose Cargo invocation contains COMMAND."
  (seq-filter (lambda (runnable)
                (my/rust--runnable-command-p runnable command))
              runnables))

(defun my/rust--select-runnable (runnables prompt)
  "Select one of RUNNABLES using PROMPT.
Return the sole runnable without prompting."
  (pcase runnables
    ('() (user-error "Rust Analyzer found no matching runnable"))
    (`(,only) only)
    (_
     (let* ((indexed
             (cl-loop for runnable in runnables
                      for index from 1
                      collect
                      (cons (format "%d. %s"
                                    index
                                    (or (plist-get runnable :label)
                                        "unnamed runnable"))
                            runnable)))
            (choice (completing-read prompt indexed nil t)))
       (alist-get choice indexed nil nil #'string=)))))

(defun my/rust--environment-pairs (environment)
  "Normalize runnable ENVIRONMENT to an alist of string pairs."
  (cond
   ((hash-table-p environment)
    (let (pairs)
      (maphash (lambda (key value)
                 (push (cons (format "%s" key) (format "%s" value)) pairs))
               environment)
      (nreverse pairs)))
   ((and (listp environment)
         (or (null environment)
             (consp (car environment))))
    (mapcar (lambda (pair)
              (cons (format "%s" (car pair))
                    (format "%s" (cdr pair))))
            environment))
   ((listp environment)
    (cl-loop for (key value) on environment by #'cddr
             collect
             (cons (string-remove-prefix ":" (symbol-name key))
                   (format "%s" value))))
   (t nil)))

(defun my/rust--runnable-environment (runnable)
  "Return RUNNABLE's environment as an alist."
  (my/rust--environment-pairs
   (plist-get (my/rust--runnable-args runnable) :environment)))

(defun my/rust--runnable-directory (runnable)
  "Return RUNNABLE's working directory."
  (file-name-as-directory
   (or (plist-get (my/rust--runnable-args runnable) :cwd)
       (my/rust-project-root))))

(defun my/rust--shell-join (arguments)
  "Quote and join ARGUMENTS for execution by a shell."
  (mapconcat #'shell-quote-argument arguments " "))

(defun my/rust--runnable-command (runnable)
  "Return the shell command represented by RUNNABLE."
  (let ((args (my/rust--runnable-args runnable)))
    (cond
     ((my/rust--runnable-cargo-p runnable)
      (my/rust--shell-join
       (append
        (list (or (plist-get args :overrideCargo) "cargo"))
        (my/rust--runnable-cargo-args runnable)
        (when-let* ((executable-args
                     (my/rust--runnable-executable-args runnable)))
          (append (list "--") executable-args)))))
     ((my/rust--runnable-shell-p runnable)
      (my/rust--shell-join
       (cons (plist-get args :program)
             (append (plist-get args :args) nil))))
     (t
      (user-error "Unsupported Rust Analyzer runnable kind: %s"
                  (plist-get runnable :kind))))))

(defun my/rust--run-runnable (runnable)
  "Run RUNNABLE in a compilation buffer."
  (let ((default-directory (my/rust--runnable-directory runnable))
        (process-environment (copy-sequence process-environment)))
    (dolist (pair (my/rust--runnable-environment runnable))
      (setenv (car pair) (cdr pair)))
    (compile (my/rust--runnable-command runnable))))

(defun my/rust-runnable-at-point ()
  "Choose and run a Rust Analyzer runnable at point."
  (interactive)
  (let ((runnables (or (my/rust--runnables)
                       (my/rust--runnables t))))
    (my/rust--run-runnable
     (my/rust--select-runnable runnables "Run: "))))

(defun my/rust-run-test-at-point ()
  "Run the Rust test or test module at point."
  (interactive)
  (my/rust--run-runnable
   (my/rust--select-runnable
    (my/rust--filter-runnables (my/rust--runnables) "test")
    "Run test: ")))

(defun my/rust-run-test-file ()
  "Run a test target or module associated with the current Rust file."
  (interactive)
  (my/rust--run-runnable
   (my/rust--select-runnable
    (my/rust--filter-runnables (my/rust--runnables t) "test")
    "Run tests for file/module: ")))

(defun my/rust-run-test-project ()
  "Run all tests in the current Cargo workspace."
  (interactive)
  (unless (executable-find "cargo")
    (user-error "Install the Rust toolchain to run Cargo tests"))
  (let ((default-directory (my/rust-project-root)))
    (compile "cargo test --workspace")))

(defun my/rust-run-benchmark-at-point ()
  "Run the Rust benchmark at point."
  (interactive)
  (my/rust--run-runnable
   (my/rust--select-runnable
    (my/rust--filter-runnables (my/rust--runnables) "bench")
    "Run benchmark: ")))

;; ---------------------------------------------------------------------------
;; lldb-dap / Dape
;; ---------------------------------------------------------------------------

(defun my/rust--ensure-lldb-dap (config)
  "Ensure the lldb-dap command in Dape CONFIG is available."
  (unless (if (file-name-absolute-p my/rust-lldb-dap-command)
              (file-executable-p my/rust-lldb-dap-command)
            (executable-find my/rust-lldb-dap-command))
    (user-error "Install lldb-dap or customize `my/rust-lldb-dap-command'"))
  (dape-ensure-command config))

(defun my/rust--environment-plist (environment)
  "Convert ENVIRONMENT into a DAP-compatible plist."
  (cl-loop for (key . value) in (my/rust--environment-pairs environment)
           append (list (intern (concat ":" key)) value)))

(defun my/rust--argument-value (arguments option)
  "Return OPTION's value in Cargo ARGUMENTS.
Both `--option value' and `--option=value' forms are supported."
  (cl-loop for tail on arguments
           for argument = (car tail)
           when (string= argument option)
           return (cadr tail)
           when (string-prefix-p (concat option "=") argument)
           return (substring argument (1+ (length option)))))

(defun my/rust--cargo-command-index (arguments)
  "Return the index of the Cargo subcommand in ARGUMENTS."
  (cl-position-if
   (lambda (argument)
     (member argument '("run" "build" "test" "bench")))
   arguments))

(defun my/rust--debug-build-arguments (runnable)
  "Return build-only Cargo arguments for RUNNABLE.
Every build emits JSON so generated and nonstandard artifacts can be found."
  (unless (my/rust--runnable-cargo-p runnable)
    (user-error "Only Cargo runnables can be debugged with lldb-dap"))
  (let* ((arguments (copy-sequence
                     (my/rust--runnable-cargo-args runnable)))
         (command-index (my/rust--cargo-command-index arguments))
         (command (and command-index (nth command-index arguments))))
    (unless command
      (user-error "Unsupported Cargo runnable: no build, run, test, or bench command"))
    (when (and (string= command "test") (member "--doc" arguments))
      (user-error "Cargo cannot build doctests with --no-run for lldb-dap"))
    (when (string= command "run")
      (setf (nth command-index arguments) "build"))
    (append
     (cl-subseq arguments 0 (1+ command-index))
     '("--message-format=json-render-diagnostics")
     (when (and (member command '("test" "bench"))
                (not (member "--no-run" arguments)))
       '("--no-run"))
     (when (and (string= command "bench")
                (not (my/rust--argument-value arguments "--profile"))
                (not (member "--release" arguments)))
       '("--profile=dev"))
     (cl-subseq arguments (1+ command-index)))))

(defun my/rust--debug-command (runnable)
  "Return the Cargo command list used to build RUNNABLE for debugging."
  (let* ((args (my/rust--runnable-args runnable))
         (cargo (or (plist-get args :overrideCargo) "cargo")))
    (cons cargo (my/rust--debug-build-arguments runnable))))

(defun my/rust--predicted-binary (runnable)
  "Return RUNNABLE's predictable ordinary binary path, or nil.
The Cargo JSON output remains the fallback when configuration changes the
layout or the runnable does not identify one normal binary."
  (let* ((arguments (my/rust--runnable-cargo-args runnable))
         (command-index (my/rust--cargo-command-index arguments))
         (command (and command-index (nth command-index arguments)))
         (binary (my/rust--argument-value arguments "--bin")))
    (when (and (string= command "run") binary)
      (let* ((cwd (my/rust--runnable-directory runnable))
             (environment (my/rust--runnable-environment runnable))
             (configured-target-dir
              (or (my/rust--argument-value arguments "--target-dir")
                  (cdr (assoc "CARGO_TARGET_DIR" environment))
                  "target"))
             (target-dir (expand-file-name configured-target-dir cwd))
             (target (my/rust--argument-value arguments "--target"))
             (profile (cond
                       ((member "--release" arguments) "release")
                       ((my/rust--argument-value arguments "--profile"))
                       (t "debug")))
             (suffix (if (eq system-type 'windows-nt) ".exe" "")))
        (expand-file-name
         (concat binary suffix)
         (file-name-concat target-dir
                           (or target "")
                           profile))))))

(defun my/rust--cargo-artifacts-in-buffer (buffer)
  "Return executable Cargo artifact messages parsed from BUFFER."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (let (artifacts)
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (when (string-prefix-p "{" line)
              (when-let* ((message
                           (ignore-errors
                             (json-parse-string
                              line :object-type 'plist :array-type 'list
                              :null-object nil :false-object nil)))
                          ((equal (plist-get message :reason)
                                  "compiler-artifact"))
                          ((stringp (plist-get message :executable))))
                (push message artifacts))))
          (forward-line 1))
        (nreverse artifacts)))))

(defun my/rust--artifact-score (artifact runnable)
  "Return how closely ARTIFACT matches Cargo RUNNABLE."
  (let* ((arguments (my/rust--runnable-cargo-args runnable))
         (command-index (my/rust--cargo-command-index arguments))
         (command (and command-index (nth command-index arguments)))
         (target (plist-get artifact :target))
         (profile (plist-get artifact :profile))
         (kinds (plist-get target :kind))
         (name (plist-get target :name))
         (selected-kind
          (cl-loop for (option . kind)
                   in '(("--bin" . "bin")
                        ("--example" . "example")
                        ("--test" . "test")
                        ("--bench" . "bench"))
                   when (my/rust--argument-value arguments option)
                   return kind))
         (selected-name
          (cl-loop for option in '("--bin" "--example" "--test" "--bench")
                   thereis (my/rust--argument-value arguments option))))
    (+ (if (and selected-name (equal name selected-name)) 100 0)
       (if (and selected-kind (member selected-kind kinds)) 50 0)
       (if (and (member "--lib" arguments) (member "lib" kinds)) 75 0)
       (if (and (string= command "run") (member "bin" kinds)) 25 0)
       (if (and (member command '("test" "bench"))
                (plist-get profile :test))
           25
         0))))

(defun my/rust--select-debug-artifact (artifacts runnable)
  "Return the best executable from ARTIFACTS for RUNNABLE.
Prompt only when Cargo reports multiple equally suitable executables."
  (unless artifacts
    (user-error "Cargo did not report an executable artifact"))
  (let* ((artifacts
          (seq-uniq artifacts
                    (lambda (left right)
                      (equal (plist-get left :executable)
                             (plist-get right :executable)))))
         (scored
          (mapcar (lambda (artifact)
                    (cons (my/rust--artifact-score artifact runnable) artifact))
                  artifacts))
         (best-score (apply #'max (mapcar #'car scored)))
         (best (mapcar #'cdr
                       (seq-filter (lambda (entry)
                                     (= (car entry) best-score))
                                   scored))))
    (if (= (length best) 1)
        (plist-get (car best) :executable)
      (let* ((choices
              (mapcar
               (lambda (artifact)
                 (let ((target (plist-get artifact :target)))
                   (cons (format "%s (%s)"
                                 (plist-get target :name)
                                 (string-join (plist-get target :kind) ", "))
                         (plist-get artifact :executable))))
               best))
             (choice (completing-read "Debug Cargo artifact: " choices nil t)))
        (alist-get choice choices nil nil #'string=)))))

(defun my/rust--lldb-quote (path)
  "Quote PATH for use in an LLDB command."
  (concat "\"" (replace-regexp-in-string "[\\\\\"]" "\\\\\\&" path) "\""))

(defun my/rust--rust-sysroot ()
  "Return the active Rust sysroot, or nil when rustc is unavailable."
  (when (executable-find "rustc")
    (with-temp-buffer
      (when (eq 0 (call-process "rustc" nil t nil "--print" "sysroot"))
        (let ((output (string-trim (buffer-string))))
          (unless (string-empty-p output) output))))))

(defun my/rust--lldb-init-commands ()
  "Return LLDB commands which install Rust's toolchain pretty-printers."
  (or
   (when-let* ((sysroot (my/rust--rust-sysroot))
               (etc-directory
                (file-name-concat sysroot "lib" "rustlib" "etc"))
               (lookup (file-name-concat etc-directory "lldb_lookup.py"))
               (commands (file-name-concat etc-directory "lldb_commands"))
               ((file-readable-p lookup))
               ((file-readable-p commands)))
     (vector
      (concat "command script import " (my/rust--lldb-quote lookup))
      (concat "command source " (my/rust--lldb-quote commands))))
   []))

(defun my/rust--dape-config (runnable executable)
  "Return an lldb-dap configuration for RUNNABLE and EXECUTABLE."
  (let* ((args (my/rust--runnable-args runnable))
         (cwd (my/rust--runnable-directory runnable))
         (executable-args
          (vconcat (my/rust--runnable-executable-args runnable)))
         (environment (my/rust--environment-plist
                       (plist-get args :environment)))
         (init-commands (my/rust--lldb-init-commands)))
    `(rust-lldb-dap
      modes (rust-ts-mode rust-mode)
      ensure my/rust--ensure-lldb-dap
      command ,my/rust-lldb-dap-command
      command-cwd ,cwd
      :type "lldb-dap"
      :request "launch"
      :program ,executable
      :cwd ,cwd
      :env ,environment
      :args ,executable-args
      :initCommands ,init-commands
      :stopOnEntry nil)))

(defun my/rust--debug-build-finished (process _event)
  "Start lldb-dap after Cargo build PROCESS exits successfully."
  (when (memq (process-status process) '(exit signal))
    (let* ((buffer (process-buffer process))
           (runnable (process-get process 'my/rust-runnable))
           (predicted (process-get process 'my/rust-predicted))
           (status (process-exit-status process)))
      (if (not (zerop status))
          (message "Cargo debug build failed; see %s" (buffer-name buffer))
        (condition-case error-data
            (let* ((artifacts (my/rust--cargo-artifacts-in-buffer buffer))
                   (reported-p
                    (and predicted
                         (seq-some
                          (lambda (artifact)
                            (equal
                             (expand-file-name
                              (plist-get artifact :executable))
                             (expand-file-name predicted)))
                          artifacts)))
                   (executable
                    (if (and reported-p (file-executable-p predicted))
                        predicted
                      (my/rust--select-debug-artifact artifacts runnable))))
              (message "Starting lldb-dap for %s"
                       (file-relative-name
                        executable (my/rust--runnable-directory runnable)))
              (dape (my/rust--dape-config runnable executable)))
          (error
           (message "Unable to start Rust debugger: %s"
                    (error-message-string error-data))))))))

(defun my/rust--debug-runnable (runnable)
  "Build RUNNABLE asynchronously and debug it with lldb-dap."
  (unless (my/rust--runnable-cargo-p runnable)
    (user-error "Only Cargo runnables can be debugged with lldb-dap"))
  (let ((cargo-command (car (my/rust--debug-command runnable))))
    (unless (if (file-name-absolute-p cargo-command)
                (file-executable-p cargo-command)
              (executable-find cargo-command))
      (user-error "Unable to find Cargo command %s" cargo-command)))
  (unless (if (file-name-absolute-p my/rust-lldb-dap-command)
              (file-executable-p my/rust-lldb-dap-command)
            (executable-find my/rust-lldb-dap-command))
    (user-error "Install lldb-dap or customize `my/rust-lldb-dap-command'"))
  (let* ((default-directory (my/rust--runnable-directory runnable))
         (process-environment (copy-sequence process-environment))
         (buffer (get-buffer-create "*rust-cargo-debug*"))
         (command (my/rust--debug-command runnable))
         (predicted (my/rust--predicted-binary runnable)))
    (when (process-live-p (get-buffer-process buffer))
      (user-error "A Rust debug build is already running"))
    (dolist (pair (my/rust--runnable-environment runnable))
      (setenv (car pair) (cdr pair)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "$ %s\n\n" (my/rust--shell-join command)))
        (compilation-mode)))
    (make-process
     :name "rust-cargo-debug"
     :buffer buffer
     :command command
     :noquery t
     :sentinel
     (lambda (process event)
       (process-put process 'my/rust-runnable runnable)
       (process-put process 'my/rust-predicted predicted)
       (my/rust--debug-build-finished process event)))
    (display-buffer buffer)
    (message "Building Rust debug target...")))

(defun my/rust-debug-runnable-at-point ()
  "Choose, build, and debug a Cargo runnable at point with lldb-dap."
  (interactive)
  (let* ((runnables (or (my/rust--runnables)
                        (my/rust--runnables t)))
         (cargo-runnables
          (seq-filter #'my/rust--runnable-cargo-p runnables))
         (runnable
          (my/rust--select-runnable cargo-runnables "Debug: ")))
    (my/rust--debug-runnable runnable))
  (setq repeat-map 'my/debug-repeat-map))

(defun my/rust-debug-test-at-point ()
  "Build and debug the Rust test or test module at point with lldb-dap."
  (interactive)
  (let ((runnable
         (my/rust--select-runnable
          (my/rust--filter-runnables (my/rust--runnables) "test")
          "Debug test: ")))
    (my/rust--debug-runnable runnable))
  (setq repeat-map 'my/debug-repeat-map))

(put 'my/rust-debug-test-at-point 'repeat-map 'my/debug-repeat-map)
(put 'my/rust-debug-runnable-at-point 'repeat-map 'my/debug-repeat-map)

;; ---------------------------------------------------------------------------
;; Coverage
;; ---------------------------------------------------------------------------

(defun my/rust--coverage-finished (buffer status root coverage-file)
  "Load COVERAGE-FILE for ROOT when BUFFER exits successfully with STATUS."
  (when (string-match-p "\\`finished" status)
    (if (file-readable-p coverage-file)
        (progn
          (require 'coverlay)
          (setq coverlay:base-path root)
          (coverlay-load-file coverage-file)
          (message "Rust coverage loaded from %s" coverage-file))
      (message "cargo llvm-cov succeeded but did not create %s"
               coverage-file)))
  (unless (string-match-p "\\`finished" status)
    (message "Rust coverage failed; see %s" (buffer-name buffer))))

(defun my/rust-coverage ()
  "Run workspace coverage and display inline results with Coverlay."
  (interactive)
  (unless (executable-find "cargo")
    (user-error "Install the Rust toolchain to generate coverage"))
  (unless
      (eq 0 (call-process "cargo" nil nil nil "llvm-cov" "--version"))
    (user-error "Install cargo-llvm-cov to generate Rust coverage"))
  (let* ((root (my/rust-project-root))
         (default-directory root)
         (coverage-file (expand-file-name my/rust-coverage-file root))
         (command
          (my/rust--shell-join
           (list "cargo" "llvm-cov" "--workspace" "--lcov"
                 "--output-path" coverage-file)))
         (buffer
          (compilation-start command 'compilation-mode
                             (lambda (_) "*rust-coverage*"))))
    (with-current-buffer buffer
      (add-hook
       'compilation-finish-functions
       (lambda (finished-buffer status)
         (my/rust--coverage-finished
          finished-buffer status root coverage-file))
       nil t))))

;; ---------------------------------------------------------------------------
;; Rust-specific navigation and views
;; ---------------------------------------------------------------------------

(defun my/rust--display-text (buffer-name text mode)
  "Display TEXT in BUFFER-NAME using MODE."
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert text)
        (goto-char (point-min))
        (funcall mode)
        (view-mode 1)))
    (pop-to-buffer buffer)))

(defun my/rust-expand-macro ()
  "Show the Rust Analyzer macro expansion at point."
  (interactive)
  (let ((response
         (my/rust--request :rust-analyzer/expandMacro
                           (my/rust--position-params))))
    (unless response
      (user-error "No macro expansion is available at point"))
    (my/rust--display-text
     (format "*rust macro: %s*" (or (plist-get response :name) "expansion"))
     (plist-get response :expansion)
     (major-mode-remap 'rust-mode))))

(defun my/rust--goto-location (location)
  "Visit an LSP LOCATION or LocationLink."
  (unless location
    (user-error "Rust Analyzer returned no location"))
  (let* ((uri (or (plist-get location :uri)
                  (plist-get location :targetUri)))
         (range (or (plist-get location :range)
                    (plist-get location :targetSelectionRange))))
    (unless (and uri range)
      (user-error "Rust Analyzer returned an invalid location"))
    (xref-push-marker-stack)
    (pop-to-buffer (find-file-noselect (eglot-uri-to-path uri)))
    (goto-char (car (eglot-range-region range)))))

(defun my/rust-goto-parent-module ()
  "Visit the parent module declaration for the current Rust source."
  (interactive)
  (let ((response
         (my/rust--request :experimental/parentModule
                           (my/rust--position-params))))
    (my/rust--goto-location
     (if (vectorp response) (aref response 0) response))))

(defun my/rust-open-cargo-toml ()
  "Open the Cargo.toml associated with the current Rust source."
  (interactive)
  (let ((response
         (my/rust--request
          :experimental/openCargoToml
          (list :textDocument
                (plist-get (my/rust--position-params) :textDocument)))))
    (if response
        (my/rust--goto-location response)
      (find-file (expand-file-name "Cargo.toml" (my/rust-project-root))))))

(defvar my/rust-mode-bindings
  '(("C-c t t" . my/rust-run-test-at-point)
    ("C-c t d" . my/rust-debug-test-at-point)
    ("C-c t f" . my/rust-run-test-file)
    ("C-c t p" . my/rust-run-test-project)
    ("C-c t b" . my/rust-run-benchmark-at-point)
    ("C-c t c" . my/rust-coverage)
    ("C-c t r" . my/rust-runnable-at-point)
    ("C-c t D" . my/rust-debug-runnable-at-point)
    ("C-c g i" . eglot-find-implementation)
    ("C-c g t" . eglot-find-typeDefinition)
    ("C-c g c" . eglot-show-call-hierarchy)
    ("C-c g p" . my/rust-goto-parent-module)
    ("C-c g m" . my/rust-expand-macro)
    ("C-c g o" . my/rust-open-cargo-toml)
    ("M-." . xref-find-definitions)
    ("M-," . xref-go-back)
    ("M-?" . xref-find-references))
  "Bindings shared by `rust-ts-mode' and `rust-mode'.")

(defun my/rust-install-bindings (map)
  "Install Rust IDE bindings in MAP."
  (dolist (binding my/rust-mode-bindings)
    (define-key map (kbd (car binding)) (cdr binding))))

;; ---------------------------------------------------------------------------
;; Package and mode registration
;; ---------------------------------------------------------------------------

(with-eval-after-load 'eglot
  (add-to-list
   'eglot-server-programs
   `((rust-ts-mode rust-mode)
     . ("rust-analyzer"
        :initializationOptions ,(my/rust-analyzer-settings))))
  (add-to-list 'eglot-server-programs
               '((toml-ts-mode conf-toml-mode)
                 . ("taplo" "lsp" "stdio")))
  (setq-default eglot-workspace-configuration
                (my/rust-merge-workspace-configuration
                 (default-value 'eglot-workspace-configuration))))

(with-eval-after-load 'apheleia
  (setf (alist-get 'rust-ts-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'rust-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'taplo apheleia-formatters)
        '("taplo" "format" "-"))
  (setf (alist-get 'toml-ts-mode apheleia-mode-alist) 'taplo)
  (setf (alist-get 'conf-toml-mode apheleia-mode-alist) 'taplo))

(with-eval-after-load 'dape
  (add-to-list
   'dape-configs
   `(rust-lldb-dap
     modes (rust-ts-mode rust-mode)
     ensure my/rust--ensure-lldb-dap
     command ,my/rust-lldb-dap-command
     command-cwd dape-command-cwd
     :type "lldb-dap"
     :request "launch"
     :program "target/debug/a.out"
     :initCommands my/rust--lldb-init-commands
     :cwd dape-cwd
     :args []
     :stopOnEntry nil)))

(use-package rust-ts-mode
  :ensure nil
  :hook (rust-ts-mode . my/rust-mode-setup)
  :config
  (my/rust-install-bindings rust-ts-mode-map))

(use-package rust-mode
  :ensure t
  :mode ("\\.rs\\'" . rust-mode)
  :hook (rust-mode . my/rust-mode-setup)
  :config
  (my/rust-install-bindings rust-mode-map))

(use-package conf-mode
  :ensure nil
  :mode ("\\.toml\\'" . conf-toml-mode)
  :hook (conf-toml-mode . my/rust-toml-setup))

(use-package toml-ts-mode
  :ensure nil
  :hook (toml-ts-mode . my/rust-toml-setup))

(use-package coverlay
  :ensure t
  :commands (coverlay-load-file
             coverlay-reload-file
             coverlay-toggle-overlays
             coverlay-display-stats)
  :config
  (setq coverlay:tested-line-background-color "#294436"
        coverlay:untested-line-background-color "#3c2626"
        coverlay:mark-tested-lines t))

(provide 'ide-rust)

;;; ide-rust.el ends here

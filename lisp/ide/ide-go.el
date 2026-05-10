;;; init-go.el --- Go language configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Full Go IDE setup built on:
;;   go-ts-mode   — tree-sitter based major mode (built-in, Emacs 29+)
;;   eglot        — LSP client connecting to gopls
;;   dape         — DAP debugger connecting to delve
;;   apheleia     — non-blocking code formatting (gofmt / goimports)
;;   gotest       — run Go tests from inside Emacs
;;
;; External tools required on your PATH:
;;   gopls        — Go LSP server:       go install golang.org/x/tools/gopls@latest
;;   delve        — Go debugger:         go install github.com/go-delve/delve/cmd/dlv@latest
;;   goimports    — formatter+imports:   go install golang.org/x/tools/cmd/goimports@latest
;;
;; On NixOS add these to your devShell or environment.systemPackages:
;;   gopls, delve, gotools (provides goimports)

;;; Code:

;; ----------------------------------------------------------------------------
;; go-ts-mode — tree-sitter major mode for Go
;; ----------------------------------------------------------------------------

;; Emacs 29+ ships go-ts-mode built-in. It requires the Go tree-sitter grammar
;; to be compiled and available. On NixOS, set
;;   programs.emacs.treeSitterGrammars = with pkgs.tree-sitter-grammars; [ tree-sitter-go ];
;; or call M-x treesit-install-language-grammar RET go manually.
;;
;; We do NOT use the older go-mode from MELPA — go-ts-mode supersedes it with
;; better syntax highlighting, more accurate indentation, and structural
;; navigation via tree-sitter queries.

(use-package go-ts-mode
  :ensure nil ; built-in since Emacs 29
  :mode "\\.go\\'"  ; open .go files in go-ts-mode automatically
  :hook
  ;; Yasnippet minor mode
  (go-ts-mode . yas-minor-mode)

  ;; Start the LSP server (gopls) as soon as a Go buffer opens.
  (go-ts-mode . eglot-ensure)

  ;; Enable combobulate-mode
  (go-ts-mode . combobulate-mode)
  
  ;; Go mandates tabs for indentation. Override the global spaces default
  ;; set in init-defaults.el.
  (go-ts-mode . (lambda ()
                  (setq indent-tabs-mode t)
                  (setq tab-width 4)
                  (setq-local completion-at-point-functions
                              (list (cape-capf-super
                                     #'eglot-completion-at-point
                                     #'yasnippet-capf)))))
  :config
  ;; Tell Emacs that .go files should use go-ts-mode (belt-and-suspenders
  ;; alongside the :mode keyword above).
  (add-to-list 'major-mode-remap-alist '(go-mode . go-ts-mode))
  
  ;; We use apheleia with goimports and gofumpt formatters in go-ts-mode
  (with-eval-after-load 'apheleia
    (setf (alist-get 'goimports apheleia-formatters)
          '("goimports" "-w" file))
    (setf (alist-get 'gofumpt apheleia-formatters)
          '("gofumpt"))
    (setf (alist-get 'go-ts-mode apheleia-mode-alist)
          '(goimports gofumpt)))
  
  ;; Configure delve as the debug adapter for Go.
  (with-eval-after-load 'dape
    ;; `dlv-test' launches the test function nearest to the cursor.
    (add-to-list 'dape-configs
                 `(dlv-test
                   modes (go-ts-mode)
                   command "dlv"
                   command-args ("dap" "--listen" "127.0.0.1:55878")
                   command-cwd dape-command-cwd
                   host "127.0.0.1"
                   port 55878
                   :type "go"
                   :request "launch"
                   :mode "test"
                   :program "."
                   :args []))
    
    ;; dlv: the regular debug config
    (add-to-list 'dape-configs
                 `(dlv
                   modes (go-ts-mode)
                   command "dlv"
                   command-args ("dap" "--listen" "127.0.0.1:55879") ; different port
                   command-cwd dape-command-cwd
                   host "127.0.0.1"
                   port 55879
                   :type "go"
                   :request "launch"
                   :mode "debug"
                   :program "."
                   :args [])))

  ;; When working in a Go module, tell Projectile to treat the module root
  ;; (where go.mod lives) as the project root rather than the git root.
  ;; This keeps the tree focused on the Go workspace.
  (with-eval-after-load 'projectile
    (projectile-register-project-type
     'go '("go.mod")
     :project-file "go.mod"
     :compile "go build ./..."
     :test "go test ./..."
     :test-suffix "_test"))
  )

;; ----------------------------------------------------------------------------
;; gotest — run Go tests without leaving Emacs
;; ----------------------------------------------------------------------------

;; gotest provides commands to run the test at point, all tests in the current
;; package, or the full test suite. Output appears in a dedicated buffer.
(use-package gotest
  :after go-ts-mode
  :bind (:map go-ts-mode-map
              ("C-c t t" . my/go-run-test-at-point)     ; run test at point
              ("C-c t d" . my/go-debug-test-at-point)  ; debug test/subtest at point
              ("C-c t f" . go-test-current-file)     ; run all tests in file
              ("C-c t p" . go-test-current-project)  ; run all tests in project
              ("C-c t b" . go-test-current-benchmark) ; run benchmark at point
              ("C-c t c" . go-coverage)))             ; show coverage overlay

;; ----------------------------------------------------------------------------
;; go-tag — add/remove struct field tags
;; ----------------------------------------------------------------------------

;; go-tag wraps the `gomodifytags' tool to add or remove JSON/YAML/db struct
;; tags in one keystroke. Install the tool with:
;;   go install github.com/fatih/gomodifytags@latest
(use-package go-tag
  :ensure t
  :after go-ts-mode
  :config
  (setq go-tag-args (list "-transform" "camelcase"))
  :bind (:map go-ts-mode-map
              ("C-c g a" . go-tag-add)    ; add tags to struct field(s)
              ("C-c g r" . go-tag-remove) ; remove tags from struct field(s)
              ))

;; ----------------------------------------------------------------------------
;; Structural editing (repeat-mode, combobulate, eglot)
;; ----------------------------------------------------------------------------

;; Navigation (Eglot / xref)
(defun go-goto-definition ()
  (interactive)
  (call-interactively #'xref-find-definitions))

(defun go-goto-references ()
  (interactive)
  (call-interactively #'xref-find-references))

(defun go-pop-back ()
  (interactive)
  (call-interactively #'xref-pop-marker-stack))

;; Keybindings for Go
(with-eval-after-load 'go-ts-mode
  ;; LSP navigation (consistent with your eglot config)
  (define-key go-ts-mode-map (kbd "M-.") #'go-goto-definition)
  (define-key go-ts-mode-map (kbd "M-,") #'go-pop-back)
  (define-key go-ts-mode-map (kbd "M-?") #'go-goto-references))

;; ----------------------------------------------------------------------------
;; Subtest detection and execution helpers
;; ----------------------------------------------------------------------------

(defun my/go--node-text (node)
  "Return the source text of a tree-sitter NODE."
  (when node
    (buffer-substring-no-properties
     (treesit-node-start node)
     (treesit-node-end node))))

(defun my/go--find-trun-call (node)
  "Walk up the AST from NODE to find the enclosing t.Run call_expression.
Returns the call_expression node or nil if not inside a t.Run call."
  (let ((current (my/go--find-parent-of-type node "call_expression")))
    (while (and current
                (not (let* ((func-node (my/go--find-named-child current "function"))
                            (func-text (my/go--node-text func-node)))
                       (string= func-text "t.Run"))))
      (setq current (my/go--find-parent-of-type current "call_expression")))
    current))

(defun my/go--find-parent-of-type (node &rest types)
  "Walk up the tree-sitter AST from NODE until a node of one of TYPES is found.
Returns the matching node or nil if none is found before the root."
  (let ((current (treesit-node-parent node)))
    (while (and current
                (not (member (treesit-node-type current) types)))
      (setq current (treesit-node-parent current)))
    current))

(defun my/go--find-child-of-type (node type)
  "Return the first direct child of NODE with the given TYPE."
  (let ((i 0)
        (count (treesit-node-child-count node))
        result)
    (while (and (< i count) (not result))
      (let ((child (treesit-node-child node i)))
        (when (string= (treesit-node-type child) type)
          (setq result child)))
      (setq i (1+ i)))
    result))

(defun my/go--find-all-children-of-type (node type)
  "Return all direct children of NODE with the given TYPE."
  (let ((i 0)
        (count (treesit-node-child-count node))
        results)
    (while (< i count)
      (let ((child (treesit-node-child node i)))
        (when (string= (treesit-node-type child) type)
          (push child results)))
      (setq i (1+ i)))
    (nreverse results)))

(defun my/go--find-named-child (node field-name)
  "Return the named field FIELD-NAME of NODE using tree-sitter field access."
  (treesit-node-child-by-field-name node field-name))

(defun my/go--extract-map-keys (map-node)
  "Extract string keys from a map composite literal MAP-NODE.
Returns a list of strings representing the map keys, or nil if
the keys cannot be statically determined."
  (let ((literal-value (my/go--find-child-of-type map-node "literal_value")))
    (when literal-value
      (let (keys)
        (dotimes (i (treesit-node-child-count literal-value t))
          (let ((child (treesit-node-child literal-value i t)))
            (when (string= (treesit-node-type child) "keyed_element")
              ;; key is: keyed_element -> literal_element -> interpreted_string_literal
              (let* ((literal-elem (treesit-node-child child 0 t))
                     (key-node (if (string= (treesit-node-type literal-elem)
                                            "literal_element")
                                   (treesit-node-child literal-elem 0 t)
                                 literal-elem))
                     (key-type (treesit-node-type key-node))
                     (key-text (my/go--node-text key-node)))
                (when (member key-type '("interpreted_string_literal"
                                         "raw_string_literal"))
                  (push (substring key-text 1 (1- (length key-text)))
                        keys))))))
        (nreverse keys)))))

(defun my/go--find-struct-name-field (struct-type var-name)
  "Given a struct type name STRUCT-TYPE, find which field is likely the test name.
Searches the current buffer for the struct definition and looks for
a string field that is commonly used as a test name: 'name', 'testName',
'description', 'desc', 'scenario'. VAR-NAME is the loop variable used
to access the struct (e.g. 'tc' in 'tc.name') and is used to detect
field access patterns near the t.Run call."
  ;; First try: look for tc.FieldName pattern near t.Run in the source
  ;; This handles the case where the user uses e.g. tc.description
  (save-excursion
    (let ((name-field nil))
      ;; Search forward a few lines from point for t.Run(var.Field, ...)
      (save-excursion
        (when (re-search-forward
               (concat "t\\.Run(" var-name
                       "\\.\\([A-Za-z][A-Za-z0-9]*\\)")
               nil t)
          (setq name-field (match-string 1))))
      (or name-field
          ;; Fallback: find the struct definition and look for known name fields
          (save-excursion
            (goto-char (point-min))
            (when (re-search-forward
                   (concat "type " struct-type " struct {") nil t)
              (let ((struct-start (point))
                    (struct-end (save-excursion
                                  (search-forward "}")
                                  (point)))
                    found)
                (goto-char struct-start)
                (while (and (< (point) struct-end) (not found))
                  (when (re-search-forward
                         "\\b\\(name\\|testName\\|description\\|desc\\|scenario\\|title\\)\\b"
                         struct-end t)
                    (setq found (match-string 1))))
                found)))))))

(defun my/go--extract-slice-names (slice-node name-field)
  "Extract NAME-FIELD values from a slice of struct literals SLICE-NODE.
Returns a list of strings, one per struct element in the slice."
  (let ((literal-value (my/go--find-child-of-type slice-node "literal_value")))
    (when literal-value
      (let (names)
        (dotimes (i (treesit-node-child-count literal-value t))
          (let* ((literal-elem (treesit-node-child literal-value i t))
                 (struct-body
                  (when (string= (treesit-node-type literal-elem) "literal_element")
                    (let ((inner (treesit-node-child literal-elem 0 t)))
                      (when (string= (treesit-node-type inner) "literal_value")
                        inner)))))
            (when struct-body
              (dotimes (j (treesit-node-child-count struct-body t))
                (let ((kv (treesit-node-child struct-body j t)))
                  (when (string= (treesit-node-type kv) "keyed_element")
                    (let* ((key (treesit-node-child kv 0 t))
                           (val (treesit-node-child kv 1 t)))
                      (when (and (string= (my/go--node-text key) name-field)
                                 val)
                        (let* ((actual-val
                                (if (string= (treesit-node-type val) "literal_element")
                                    (treesit-node-child val 0 t)
                                  val))
                               (val-type (treesit-node-type actual-val))
                               (val-text (my/go--node-text actual-val)))
                          (when (member val-type '("interpreted_string_literal"
                                                   "raw_string_literal"))
                            (push (substring val-text 1 (1- (length val-text)))
                                  names))))))))))); end dotimes j, when struct-body, let*, dotimes i
        (nreverse names))))) ; end let names, when literal-value, let literal-value

(defun my/go--find-var-definition (var-name)
  "Search backward from point for the definition of VAR-NAME.
Returns the tree-sitter node of the value assigned to VAR-NAME, or nil."
  (save-excursion
    (when (re-search-backward
           (concat "\\b" var-name "\\s-*:?=\\s-*") nil t)
      (let* ((node-at (treesit-node-at (point)))
             ;; Walk up to the short_var_declaration or assignment
             (decl (my/go--find-parent-of-type
                    node-at
                    "short_var_declaration"
                    "var_declaration"
                    "assignment_statement")))
        (when decl
          ;; The RHS is the last significant child — find the composite literal
          (treesit-search-subtree
           decl
           (lambda (n)
             (string= (treesit-node-type n) "composite_literal"))
           nil t))))))

(defun my/go--trun-variable-driven-p (trun-node)
  "Return info about the first argument of the t.Run call at TRUN-NODE.
Returns:
  - a string VAR-NAME if the argument is a plain identifier (map pattern)
  - a cons cell (STRUCT-VAR . FIELD-NAME) if it is a selector expression (struct pattern)
  - nil if the argument is a string literal"
  (let* ((args (my/go--find-child-of-type trun-node "argument_list"))
         (first-arg (when args (treesit-node-child args 1))))
    (pcase (treesit-node-type first-arg)
      ("identifier"
       ;; Plain variable: map pattern — return var name as string
       (my/go--node-text first-arg))
      ("selector_expression"
       ;; Struct field access: tt.name — return (struct-var . field-name)
       (let ((operand (my/go--find-named-child first-arg "operand"))
             (field   (my/go--find-named-child first-arg "field")))
         (when (and operand field)
           (cons (my/go--node-text operand)
                 (my/go--node-text field)))))
      (_ nil))))

(defun my/go--collect-table-test-names ()
  "Detect table-driven test pattern at point and return available subtest names."
  (let* ((node (treesit-node-at (point)))
         (call-node (my/go--find-trun-call node))
         (var-info (when call-node
                     (my/go--trun-variable-driven-p call-node))))
    (when var-info
      (let* ((for-node (my/go--find-parent-of-type call-node "for_statement"))
             (range-clause (when for-node
                             (my/go--find-child-of-type for-node "range_clause")))
             (range-target (when range-clause
                             (treesit-node-child
                              range-clause
                              (1- (treesit-node-child-count range-clause)))))
             (range-var (when range-target
                          (my/go--node-text range-target))))
        (when range-var
          (let ((composite (my/go--find-var-definition range-var)))
            (when composite
              (let ((type-node (treesit-node-child composite 0)))
                (cond
                 ;; Map pattern: var-info is a plain string
                 ((and (stringp var-info)
                       (string-prefix-p "map" (my/go--node-text type-node)))
                  (my/go--extract-map-keys composite))

                 ;; Struct pattern: var-info is a cons cell (struct-var . field-name)
                 ((and (consp var-info)
                       (string-prefix-p "[]" (my/go--node-text type-node)))
                  (my/go--extract-slice-names composite (cdr var-info)))

                 (t nil))))))))))

(defun my/go--enclosing-test-name ()
  "Return the name of the top-level Test/Benchmark/Fuzz function enclosing point.
Also matches when point is on the function definition line itself."
  (save-excursion
    ;; If we're on the func line itself, move to the start of the line
    ;; before searching, otherwise search backward from point.
    (or
     ;; First try: check the current line for a test function definition
     (progn
       (beginning-of-line)
       (when (re-search-forward
              "^func \\(\\(?:Test\\|Benchmark\\|Fuzz\\)[A-Za-z0-9_]*\\)"
              (line-end-position) t)
         (match-string 1)))
     ;; Second try: search backward for an enclosing test function
     (progn
       (when (re-search-backward
              "^func \\(\\(?:Test\\|Benchmark\\|Fuzz\\)[A-Za-z0-9_]*\\)" nil t)
         (match-string 1))))))

(defun my/go--subtest-names-at-point ()
  "Return a list of nested t.Run subtest names from outermost to innermost.
Handles cursor being on the t.Run line itself or inside its body."
  (save-excursion
    (let ((original-pos (point))
          (subtests '()))
      ;; First check if we're on a t.Run line itself
      (beginning-of-line)
      (if (re-search-forward
           "t\\.Run(\\(?:\"\\([^\"]+\\)\"\\|`\\([^`]+\\)`\\)"
           (line-end-position) t)
          ;; We're on a t.Run line — also collect any enclosing t.Run calls
          (let ((current-name (or (match-string 1) (match-string 2))))
            ;; Search backward for enclosing t.Run calls
            (goto-char original-pos)
            (save-excursion
              (while (re-search-backward
                      "t\\.Run(\\(?:\"\\([^\"]+\\)\"\\|`\\([^`]+\\)`\\)" nil t)
                (let* ((run-pos (point))
                       (parent-name (or (match-string 1) (match-string 2))))
                  (when parent-name
                    (when (re-search-forward "func[^{]*{" nil t)
                      (let ((brace-pos (point)))
                        (goto-char (1- brace-pos))
                        (condition-case nil
                            (progn
                              (forward-sexp)
                              (when (> (point) original-pos)
                                (push parent-name subtests)))
                          (scan-error nil)))
                      (goto-char run-pos))))))
            ;; Append the current t.Run name at the end
            (append subtests (list current-name)))
        ;; Not on a t.Run line — search backward as before
        (goto-char original-pos)
        (while (re-search-backward
                "t\\.Run(\\(?:\"\\([^\"]+\\)\"\\|`\\([^`]+\\)`\\)" nil t)
          (let* ((run-pos (point))
                 (subtest-name (or (match-string 1) (match-string 2))))
            (when subtest-name
              (when (re-search-forward "func[^{]*{" nil t)
                (let ((brace-pos (point)))
                  (goto-char (1- brace-pos))
                  (condition-case nil
                      (progn
                        (forward-sexp)
                        (when (> (point) original-pos)
                          (push subtest-name subtests)))
                    (scan-error nil)))
                (goto-char run-pos)))))
        subtests))))

(defun my/go--run-arg-at-point ()
  "Construct the -run argument for the test or subtest at point.
Returns a string like 'TestFoo', 'TestFoo/subtest', or
'TestFoo/outer/inner' for nested subtests."
  (let ((test-name (my/go--enclosing-test-name))
        (subtests  (my/go--subtest-names-at-point)))
    (when test-name
      (if subtests
          ;; Go's -run flag matches subtest names with / as separator.
          ;; Spaces in subtest names are replaced with _ by the test runner,
          ;; so we mirror that transformation here.
          (concat test-name "/"
                  (mapconcat
                   (lambda (s) (replace-regexp-in-string " " "_" s))
                   subtests "/"))
        test-name))))

(defun my/go-run-test-at-point ()
  "Run the Go test or subtest at point.

Detects context automatically:
- Inside a t.Run block          → runs that specific subtest
- Inside a nested t.Run block   → runs the full nesting chain
- Inside a Test/Benchmark func  → runs the whole top-level test
- Outside any test function     → prompts for a test name

Output appears in the *compilation* buffer where you can navigate
to file/line references in error messages with RET."
  (interactive)
  (unless (derived-mode-p 'go-ts-mode)
    (user-error "Not in a Go buffer"))
  (let ((table-names (my/go--collect-table-test-names)))
    (if table-names
        ;; Delegate to table subtest picker
        (let* ((test-name (my/go--enclosing-test-name))
               (chosen (completing-read
                        (format "Run subtest of %s: " test-name)
                        table-names nil t))
               (parts (split-string
                       (concat test-name "/" chosen) "/"))
               (test-fn (car parts))
               (subtest (when (cadr parts)
                          (replace-regexp-in-string " " "_" (cadr parts))))
               (run-regex (if subtest
                              (concat "^" test-fn "$/" subtest "$")
                            (concat "^" test-fn "$"))))
          (message "Running: go test -v -run %s" run-regex)
          (compile (concat "go test -v -run " run-regex " .")))
      ;; Fall through to regular subtest/test detection
      (let ((run-arg (or (my/go--run-arg-at-point)
                         (read-string "Test name (-run arg): "))))
        (message "Running: go test -v -run ^%s$" run-arg)
        (let* ((parts (split-string run-arg "/"))
               (test-fn (car parts))
               (subtest (when (cadr parts)
                          (replace-regexp-in-string " " "_" (cadr parts))))
               (run-regex (if subtest
                              (concat "^" test-fn "$/" subtest "$")
                            (concat "^" test-fn "$"))))
          (compile (concat "go test -v -run " run-regex " .")))))))

(defun my/go-debug-test-at-point ()
  "Debug the Go test or subtest at point using dape/delve.
Mirrors my/go-run-test-at-point but launches a debug session
instead of a plain test run."
  (interactive)
  (unless (derived-mode-p 'go-ts-mode)
    (user-error "Not in a Go buffer"))
  (let* ((table-names (my/go--collect-table-test-names))
         (run-regex
          (if table-names
              (let* ((test-name (my/go--enclosing-test-name))
                     (chosen (completing-read
                              (format "Debug subtest of %s: " test-name)
                              table-names nil t))
                     (parts (split-string
                             (concat test-name "/" chosen) "/"))
                     (test-fn (car parts))
                     (subtest (when (cadr parts)
                                (replace-regexp-in-string " " "_" (cadr parts)))))
                (if subtest
                    (concat "^" test-fn "$/" subtest "$")
                  (concat "^" test-fn "$")))
            (let* ((run-arg (or (my/go--run-arg-at-point)
                                (read-string "Test name (-run arg): ")))
                   (parts (split-string run-arg "/"))
                   (test-fn (car parts))
                   (subtest (when (cadr parts)
                              (replace-regexp-in-string " " "_" (cadr parts)))))
              (if subtest
                  (concat "^" test-fn "$/" subtest "$")
                (concat "^" test-fn "$"))))))
    (let* ((config (copy-tree (alist-get 'dlv-test dape-configs)))
           (config (plist-put config 'command-cwd default-directory))
           (config (plist-put config :program "."))
           (config (plist-put config :args
                              (vector "--test.run"
                                      (substring-no-properties run-regex)))))
      (message "Debugging: %s" run-regex)
      (dape config)))
  (setq repeat-map 'my/debug-repeat-map))

(put 'my/go-debug-test-at-point 'repeat-map 'my/debug-repeat-map)

;;; provide the feature so (require 'init-go) works from init.el
(provide 'ide-go)

;;; init-go.el ends here

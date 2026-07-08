# Emacs Configuration

Personal Emacs configuration focused on modal editing, project navigation, completion, Go development, Java development, and JSON/YAML schema-aware editing.

## Layout

- `init.el` is the entry point. It extends `load-path`, registers `themes/`, then loads the init modules.
- `lisp/init-*.el` contains top-level configuration for defaults, packages, completion, UI, navigation, and IDE support.
- `lisp/ide/` contains language/tooling modules. Go lives in `ide-go.el`; JSON/YAML lives in `ide-data.el`.
- `themes/` contains the custom `intellij-islands-dark` theme.
- Runtime state such as `elpa/`, `eln-cache/`, `backups/`, `history`, and `recentf` is intentionally not tracked.

## Emacs Requirements

Use Emacs 29 or newer. Emacs 30 is preferred because this config uses built-in `json-ts-mode`, `yaml-ts-mode`, and `go-ts-mode` where available.

On first startup, `init-packages.el` enables `package.el`, adds MELPA, bootstraps `use-package`, and installs declared Emacs packages automatically. Network access is required for that first run.

`init-navigation.el` currently loads `meow` directly with `(require 'meow)`, so install it before first startup if it is not already present:

```elisp
M-x package-refresh-contents
M-x package-install RET meow RET
```

Useful first-run font commands inside GUI Emacs:

```elisp
M-x all-the-icons-install-fonts
M-x nerd-icons-install-fonts
```

## System Dependencies

Core tools:

- `ripgrep`: used by `consult-ripgrep`.
- `direnv`: used by `envrc` for project environment loading.
- `git`: used by Magit, Projectile, and Treemacs git indicators.
- Tree-sitter grammars for `go`, `java`, `json`, and `yaml`: required for `*-ts-mode`; Java, JSON, and YAML fall back when grammars are absent.

Go development:

- `go`: Go runtime and toolchain.
- `gopls`: Go language server for Eglot.
- `dlv`: Delve debugger for Dape.
- `goimports` and `gofumpt`: formatters used by Apheleia.
- `gomodifytags`: used by `go-tag`.

Java development:

- `java` and `javac`: JDK 17+ recommended; JDTLS works best with a modern JDK.
- `jdtls`: Java language server for Eglot. Required for completion, diagnostics, `M-.`, references, code actions, and rename.
- `mvn` or `./mvnw`: Maven support for running tests.
- `gradle` or `./gradlew`: Gradle support for running tests.
- `google-java-format`: optional formatter used by Apheleia.
- Microsoft Java Debug Server plugin jars: required if you want Dape-based Java debugging through JDTLS.

JSON/YAML development:

- `vscode-json-language-server` or `vscode-json-languageserver`: JSON schema completion, validation, and `$ref` navigation.
- `yaml-language-server`: YAML schema completion, validation, and `$ref` navigation.
- `prettier`: JSON/YAML formatting through Apheleia.

The YAML language server is configured with schema mappings for OpenAPI, Kubernetes manifests, GitHub Actions workflows, and Docker Compose files.

## Installing With Nix

For NixOS/Home Manager, install the tools through your system or user package list. Attribute names can vary slightly by nixpkgs revision, but this is the intended shape:

```nix
environment.systemPackages = with pkgs; [
  git
  ripgrep
  direnv

  go
  gopls
  delve
  gotools       # provides goimports
  gofumpt
  gomodifytags

  jdk17
  jdt-language-server
  maven
  gradle
  google-java-format

  nodejs
  nodePackages.vscode-langservers-extracted
  nodePackages.yaml-language-server
  nodePackages.prettier
];

programs.emacs = {
  enable = true;
  treeSitterGrammars = with pkgs.tree-sitter-grammars; [
    tree-sitter-go
    tree-sitter-java
    tree-sitter-json
    tree-sitter-yaml
  ];
};
```

If you use a dev shell instead of global packages, include the same tools in `mkShell.packages`.

## Installing on macOS With Homebrew

Install Emacs and core command-line tools:

```sh
brew install emacs git ripgrep direnv go gopls delve goimports gofumpt gomodifytags node jdtls maven gradle google-java-format
brew install --cask microsoft-openjdk@21
```

Install Node-based language servers and formatters:

```sh
npm install -g vscode-langservers-extracted yaml-language-server prettier
```

Install icon fonts from Emacs with `M-x all-the-icons-install-fonts` and `M-x nerd-icons-install-fonts`. If font prompts fail on macOS, install a Nerd Font with Homebrew Cask and choose it in your Emacs frame:

```sh
brew install --cask font-symbols-only-nerd-font
```

## Tree-Sitter Grammars

If your package manager does not install grammars, use Emacs:

```elisp
M-x treesit-install-language-grammar RET go RET
M-x treesit-install-language-grammar RET java RET
M-x treesit-install-language-grammar RET json RET
M-x treesit-install-language-grammar RET yaml RET
```

Emacs looks for compiled grammars in `treesit-extra-load-path`, then `~/.config/emacs/tree-sitter/`, then system library paths.

## Validation

Run these from the repository root:

```sh
emacs --batch -L lisp -L lisp/ide -l init.el
emacs --batch -L lisp -L lisp/ide -f batch-byte-compile lisp/*.el lisp/ide/*.el themes/*.el
```

For interactive startup problems, use:

```sh
emacs --debug-init
```

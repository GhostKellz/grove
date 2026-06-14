# Emacs Integration for Ghostlang

This guide covers setting up Ghostlang support in Emacs using tree-sitter.

## Prerequisites

- Emacs 29+ (built-in tree-sitter support) or Emacs 27+ with `tree-sitter` package
- A C compiler (gcc, clang)

## Setup (Emacs 29+)

Emacs 29+ has built-in tree-sitter support. Use `treesit` for native integration.

### 1. Create Major Mode

Add to your Emacs config (`~/.emacs.d/init.el` or `~/.config/emacs/init.el`):

```elisp
;; Ghostlang major mode using tree-sitter
(require 'treesit)

(defvar ghostlang-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; C-style comments
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    ;; Lua-style comments
    (modify-syntax-entry ?- ". 12b" table)
    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?' "\"" table)
    table)
  "Syntax table for `ghostlang-ts-mode'.")

(defvar ghostlang-ts-font-lock-rules
  '(:language ghostlang
    :feature keyword
    ((["var" "local" "function" "if" "then" "else" "elseif"
       "while" "do" "for" "in" "repeat" "until" "return"
       "break" "continue" "end"] @font-lock-keyword-face)
     (["and" "or" "not"] @font-lock-keyword-face))

    :language ghostlang
    :feature string
    ((string_literal) @font-lock-string-face
     (escape_sequence) @font-lock-escape-face)

    :language ghostlang
    :feature number
    ((number_literal) @font-lock-number-face)

    :language ghostlang
    :feature constant
    ((boolean_literal) @font-lock-constant-face
     (null_literal) @font-lock-constant-face)

    :language ghostlang
    :feature comment
    ((comment) @font-lock-comment-face)

    :language ghostlang
    :feature function
    ((function_declaration name: (identifier) @font-lock-function-name-face)
     (call_expression function: (identifier) @font-lock-function-call-face))

    :language ghostlang
    :feature variable
    ((variable_declaration name: (identifier) @font-lock-variable-name-face)
     (parameter_list (identifier) @font-lock-variable-name-face))

    :language ghostlang
    :feature property
    ((member_expression property: (identifier) @font-lock-property-name-face)
     (object_member (identifier) @font-lock-property-name-face))

    :language ghostlang
    :feature operator
    ((["+" "-" "*" "/" "%" "==" "!=" "~=" "<" ">" "<=" ">="
       "&&" "||" "!" "?" ":" ".." "??" "?." "?["]
      @font-lock-operator-face))

    :language ghostlang
    :feature bracket
    ((["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face))

    :language ghostlang
    :feature delimiter
    (([";" "," "."] @font-lock-delimiter-face))))

(defun ghostlang-ts-setup ()
  "Setup tree-sitter for ghostlang-ts-mode."
  (setq-local treesit-font-lock-settings
              (apply #'treesit-font-lock-rules ghostlang-ts-font-lock-rules))
  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword string number constant)
                (function variable property)
                (operator bracket delimiter)))
  (treesit-major-mode-setup))

(define-derived-mode ghostlang-ts-mode prog-mode "Ghostlang"
  "Major mode for editing Ghostlang files using tree-sitter."
  :syntax-table ghostlang-ts-mode-syntax-table
  (when (treesit-ready-p 'ghostlang)
    (treesit-parser-create 'ghostlang)
    (ghostlang-ts-setup)))

;; File associations
(add-to-list 'auto-mode-alist '("\\.gla\\'" . ghostlang-ts-mode))
```

### 2. Install the Grammar

Create a grammar installation recipe:

```elisp
(add-to-list 'treesit-language-source-alist
             '(ghostlang "https://github.com/ghostkellz/tree-sitter-ghostlang"))

;; Install with: M-x treesit-install-language-grammar RET ghostlang RET
```

Or manually:

```bash
git clone https://github.com/ghostkellz/tree-sitter-ghostlang
cd tree-sitter-ghostlang
tree-sitter generate

# Build shared library for Emacs
cc -shared -fPIC -o ghostlang.so src/parser.c -I src

# Copy to Emacs tree-sitter directory
mkdir -p ~/.emacs.d/tree-sitter
cp ghostlang.so ~/.emacs.d/tree-sitter/libtree-sitter-ghostlang.so
```

### 3. Verify Installation

Open a `.gla` file and check:
- `M-x ghostlang-ts-mode` should activate
- Syntax highlighting should work
- `M-x treesit-explore-mode` shows the parse tree

## Setup (Emacs 27-28 with tree-sitter package)

For older Emacs versions, use the `tree-sitter` and `tree-sitter-langs` packages.

### 1. Install Packages

```elisp
(use-package tree-sitter
  :ensure t
  :config
  (global-tree-sitter-mode)
  (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode))

(use-package tree-sitter-langs
  :ensure t
  :after tree-sitter)
```

### 2. Add Ghostlang Grammar

The `tree-sitter-langs` package may not include Ghostlang yet. Build manually:

```bash
# Clone and build
git clone https://github.com/ghostkellz/tree-sitter-ghostlang
cd tree-sitter-ghostlang
tree-sitter generate
cc -shared -fPIC -o ghostlang.so src/parser.c -I src

# Copy to tree-sitter-langs directory
cp ghostlang.so ~/.emacs.d/elpa/tree-sitter-langs-*/bin/
```

### 3. Register the Language

```elisp
(tree-sitter-load 'ghostlang)
(add-to-list 'tree-sitter-major-mode-language-alist '(ghostlang-mode . ghostlang))
```

## Basic Mode (No Tree-Sitter)

For a simple mode without tree-sitter:

```elisp
(defvar ghostlang-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?- ". 12b" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?' "\"" table)
    table))

(defconst ghostlang-font-lock-keywords
  `(;; Keywords
    (,(regexp-opt '("var" "local" "function" "if" "then" "else" "elseif"
                    "while" "do" "for" "in" "repeat" "until" "return"
                    "break" "continue" "end" "and" "or" "not") 'symbols)
     . font-lock-keyword-face)
    ;; Built-in functions
    (,(regexp-opt '("getCurrentLine" "getLineText" "setLineText" "notify"
                    "log" "print" "pairs" "ipairs" "type" "tostring"
                    "map" "filter" "sort") 'symbols)
     . font-lock-builtin-face)
    ;; Constants
    (,(regexp-opt '("true" "false" "null" "nil") 'symbols)
     . font-lock-constant-face)
    ;; Function names
    ("function\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
     (1 font-lock-function-name-face))
    ;; Variable declarations
    ("\\(var\\|local\\)\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
     (2 font-lock-variable-name-face))))

(define-derived-mode ghostlang-mode prog-mode "Ghostlang"
  "Major mode for editing Ghostlang files."
  :syntax-table ghostlang-mode-syntax-table
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *")
  (setq-local font-lock-defaults '(ghostlang-font-lock-keywords))
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2))

(add-to-list 'auto-mode-alist '("\\.gla\\'" . ghostlang-mode))
```

## Indentation

Add smart indentation:

```elisp
(defun ghostlang-indent-line ()
  "Indent current line for Ghostlang."
  (interactive)
  (let ((indent-col 0)
        (pos (- (point-max) (point))))
    (save-excursion
      (beginning-of-line)
      (condition-case nil
          (while t
            (backward-up-list 1)
            (when (looking-at "[{\\[(]")
              (setq indent-col (+ indent-col tab-width))))
        (error nil)))
    ;; Dedent for closing brackets
    (save-excursion
      (beginning-of-line)
      (skip-chars-forward " \t")
      (when (looking-at "[}\\])]\\|end\\|else\\|elseif\\|until")
        (setq indent-col (max 0 (- indent-col tab-width)))))
    (indent-line-to indent-col)
    (when (> (- (point-max) pos) (point))
      (goto-char (- (point-max) pos)))))

(add-hook 'ghostlang-mode-hook
          (lambda () (setq-local indent-line-function #'ghostlang-indent-line)))
```

## LSP Integration (Coming Soon)

When ghostls is available:

```elisp
(use-package lsp-mode
  :hook (ghostlang-mode . lsp-deferred)
  :config
  (add-to-list 'lsp-language-id-configuration '(ghostlang-mode . "ghostlang"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("ghostls" "--stdio"))
    :major-modes '(ghostlang-mode ghostlang-ts-mode)
    :server-id 'ghostls)))
```

## Resources

- [Emacs Tree-sitter Documentation](https://www.gnu.org/software/emacs/manual/html_node/elisp/Parsing-Program-Source.html)
- [tree-sitter-ghostlang](https://github.com/ghostkellz/tree-sitter-ghostlang)
- [Ghostlang](https://github.com/ghostlang/ghostlang)

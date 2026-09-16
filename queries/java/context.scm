; Declaration-only context. Overrides nvim-treesitter-context's shipped
; query, which also treats if/for/switch/expression_statement as context --
; so the sticky header churned every time the cursor crossed a brace.
; See docs/treesitter.md.
(class_declaration body: (_) @context.end) @context
(interface_declaration body: (_) @context.end) @context
(enum_declaration body: (_) @context.end) @context
(record_declaration body: (_) @context.end) @context
(method_declaration body: (_) @context.end) @context
(constructor_declaration body: (_) @context.end) @context

; Declaration-only -- see queries/java/context.scm. The shipped query also
; matched (object), (pair), (call_expression) and (lexical_declaration),
; so every object literal became a pinned line.
(class_declaration body: (_) @context.end) @context
(interface_declaration body: (_) @context.end) @context
(method_definition body: (_) @context.end) @context
(function_declaration body: (_) @context.end) @context
(generator_function_declaration body: (_) @context.end) @context

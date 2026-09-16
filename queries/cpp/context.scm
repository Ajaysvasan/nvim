; inherits: c
; Declaration-only -- see queries/java/context.scm. The inherits line above
; pulls in the c query, which is this config's own override, not the
; plugin's.
(class_specifier body: (_) @context.end) @context
(namespace_definition body: (_) @context.end) @context

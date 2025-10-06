; Markdown folding queries for Grove
; Fold sections based on heading level
(section) @fold

; Fold ATX headings (# Heading)
(atx_heading) @fold

; Fold setext headings (underlined)
(setext_heading) @fold

; Fold code blocks
(fenced_code_block) @fold
(indented_code_block) @fold

; Fold block quotes
(block_quote) @fold

; Fold lists
(list) @fold
(list_item) @fold

; Fold tables
(table) @fold

; Fold HTML blocks
(html_block) @fold

; Fold definition lists (if supported by grammar)
(definition_list) @fold

; Fold footnote definitions
(footnote_definition) @fold

; Fold link reference definitions
(link_reference_definition) @fold

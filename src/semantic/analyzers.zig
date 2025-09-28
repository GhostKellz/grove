const std = @import("std");
const Node = @import("../core/node.zig").Node;
const Point = @import("../core/node.zig").Point;
const SemanticCursor = @import("cursor.zig").SemanticCursor;
const SemanticAnalyzer = @import("cursor.zig").SemanticAnalyzer;
const TreeTraversal = @import("traversal.zig").TreeTraversal;
const Predicates = @import("traversal.zig").Predicates;
const Languages = @import("../languages.zig").Bundled;

/// TypeScript/JavaScript semantic analyzer
pub const TypeScriptAnalyzer = struct {
    allocator: std.mem.Allocator,
    base: SemanticAnalyzer,
    traversal: TreeTraversal,

    pub fn init(allocator: std.mem.Allocator) !TypeScriptAnalyzer {
        const language = try Languages.typescript.get();
        var base = SemanticAnalyzer.init(allocator, language);

        // Register common TypeScript queries
        try base.registerQuery("functions",
            \\(function_declaration
            \\  name: (identifier) @function.name
            \\  parameters: (formal_parameters) @function.params
            \\  body: (statement_block) @function.body)
            \\
            \\(method_definition
            \\  name: (property_identifier) @method.name
            \\  parameters: (formal_parameters) @method.params
            \\  body: (statement_block) @method.body)
            \\
            \\(arrow_function
            \\  parameter: (identifier) @arrow.param
            \\  body: (_) @arrow.body)
        );

        try base.registerQuery("classes",
            \\(class_declaration
            \\  name: (type_identifier) @class.name
            \\  body: (class_body) @class.body)
        );

        try base.registerQuery("imports",
            \\(import_statement
            \\  source: (string) @import.source)
            \\
            \\(import_clause
            \\  (identifier) @import.default)
            \\
            \\(named_imports
            \\  (import_specifier
            \\    name: (identifier) @import.named))
        );

        return .{
            .allocator = allocator,
            .base = base,
            .traversal = TreeTraversal.init(allocator),
        };
    }

    pub fn deinit(self: *TypeScriptAnalyzer) void {
        self.base.deinit();
    }

    /// Find all function definitions in the current scope
    pub fn findFunctions(self: *TypeScriptAnalyzer, cursor: *SemanticCursor) ![]FunctionInfo {
        const functions_query = self.base.queries.get("functions") orelse return error.QueryNotFound;
        const matches = try cursor.queryAtCursor(functions_query, null);
        defer self.allocator.free(matches);

        var functions = std.ArrayList(FunctionInfo){};
        defer functions.deinit(self.allocator);

        var i: usize = 0;
        while (i < matches.len) {
            // Group matches by function
            if (std.mem.endsWith(u8, matches[i].capture_name, ".name")) {
                const func_info = FunctionInfo{
                    .name_node = matches[i].node,
                    .params_node = if (i + 1 < matches.len) matches[i + 1].node else null,
                    .body_node = if (i + 2 < matches.len) matches[i + 2].node else null,
                    .kind = self.getFunctionKind(matches[i].capture_name),
                };
                try functions.append(self.allocator, func_info);
                i += 3; // Skip to next function group
            } else {
                i += 1;
            }
        }

        return functions.toOwnedSlice(self.allocator);
    }

    fn getFunctionKind(self: *TypeScriptAnalyzer, capture_name: []const u8) FunctionKind {
        _ = self;
        if (std.mem.startsWith(u8, capture_name, "function")) return .function;
        if (std.mem.startsWith(u8, capture_name, "method")) return .method;
        if (std.mem.startsWith(u8, capture_name, "arrow")) return .arrow;
        return .function;
    }

    /// Find all class definitions
    pub fn findClasses(self: *TypeScriptAnalyzer, cursor: *SemanticCursor) ![]ClassInfo {
        const classes_query = self.base.queries.get("classes") orelse return error.QueryNotFound;
        const matches = try cursor.queryAtCursor(classes_query, null);
        defer self.allocator.free(matches);

        var classes = std.ArrayList(ClassInfo){};
        defer classes.deinit(self.allocator);

        var i: usize = 0;
        while (i < matches.len) {
            if (std.mem.eql(u8, matches[i].capture_name, "class.name")) {
                const class_info = ClassInfo{
                    .name_node = matches[i].node,
                    .body_node = if (i + 1 < matches.len) matches[i + 1].node else null,
                };
                try classes.append(self.allocator, class_info);
                i += 2;
            } else {
                i += 1;
            }
        }

        return classes.toOwnedSlice(self.allocator);
    }

    /// Analyze import statements
    pub fn analyzeImports(self: *TypeScriptAnalyzer, cursor: *SemanticCursor) ![]ImportInfo {
        const imports_query = self.base.queries.get("imports") orelse return error.QueryNotFound;
        const matches = try cursor.queryAtCursor(imports_query, null);
        defer self.allocator.free(matches);

        var imports = std.ArrayList(ImportInfo){};
        defer imports.deinit(self.allocator);

        for (matches) |match| {
            const import_info = ImportInfo{
                .node = match.node,
                .kind = self.getImportKind(match.capture_name),
            };
            try imports.append(self.allocator, import_info);
        }

        return imports.toOwnedSlice(self.allocator);
    }

    fn getImportKind(self: *TypeScriptAnalyzer, capture_name: []const u8) ImportKind {
        _ = self;
        if (std.mem.eql(u8, capture_name, "import.source")) return .source;
        if (std.mem.eql(u8, capture_name, "import.default")) return .default;
        if (std.mem.eql(u8, capture_name, "import.named")) return .named;
        return .source;
    }

    /// Find variable definitions and usages
    pub fn findVariables(self: *TypeScriptAnalyzer, cursor: *SemanticCursor) ![]VariableInfo {
        var context = Predicates.TypeContext{ .node_type = "identifier" };
        const identifiers = try self.traversal.findNodes(
            cursor.getCurrentNode(),
            Predicates.isType,
            null,
            &context
        );
        defer self.allocator.free(identifiers);

        var variables = std.ArrayList(VariableInfo){};
        defer variables.deinit(self.allocator);

        for (identifiers) |identifier| {
            const var_info = VariableInfo{
                .node = identifier,
                .kind = self.getVariableKind(identifier),
            };
            try variables.append(self.allocator, var_info);
        }

        return variables.toOwnedSlice(self.allocator);
    }

    fn getVariableKind(self: *TypeScriptAnalyzer, node: Node) VariableKind {
        _ = self;
        const parent = node.parent() orelse return .usage;

        const parent_type = parent.type();
        if (std.mem.eql(u8, parent_type, "variable_declarator") or
            std.mem.eql(u8, parent_type, "lexical_declaration")) {
            return .declaration;
        }

        return .usage;
    }
};

/// Zig semantic analyzer
pub const ZigAnalyzer = struct {
    allocator: std.mem.Allocator,
    base: SemanticAnalyzer,
    traversal: TreeTraversal,

    pub fn init(allocator: std.mem.Allocator) !ZigAnalyzer {
        const language = try Languages.zig.get();
        var base = SemanticAnalyzer.init(allocator, language);

        try base.registerQuery("functions",
            \\(FnDecl
            \\  name: (IDENTIFIER) @function.name
            \\  params: (ParamDeclList) @function.params
            \\  body: (Block) @function.body)
        );

        try base.registerQuery("structs",
            \\(ContainerDecl
            \\  (IDENTIFIER) @struct.name
            \\  (ContainerDeclType) @struct.type)
        );

        return .{
            .allocator = allocator,
            .base = base,
            .traversal = TreeTraversal.init(allocator),
        };
    }

    pub fn deinit(self: *ZigAnalyzer) void {
        self.base.deinit();
    }

    /// Find all function definitions
    pub fn findFunctions(self: *ZigAnalyzer, cursor: *SemanticCursor) ![]FunctionInfo {
        var context = Predicates.TypeContext{ .node_type = "FnDecl" };
        const functions = try self.traversal.findNodes(
            cursor.getCurrentNode(),
            Predicates.isType,
            null,
            &context
        );
        defer self.allocator.free(functions);

        var func_infos = std.ArrayList(FunctionInfo){};
        defer func_infos.deinit(self.allocator);

        for (functions) |func_node| {
            const func_info = FunctionInfo{
                .name_node = self.findChildOfType(func_node, "IDENTIFIER") orelse continue,
                .params_node = self.findChildOfType(func_node, "ParamDeclList"),
                .body_node = self.findChildOfType(func_node, "Block"),
                .kind = .function,
            };
            try func_infos.append(self.allocator, func_info);
        }

        return func_infos.toOwnedSlice(self.allocator);
    }

    fn findChildOfType(self: *ZigAnalyzer, parent: Node, child_type: []const u8) ?Node {
        _ = self;
        for (0..parent.childCount()) |i| {
            const child = parent.child(i);
            if (std.mem.eql(u8, child.type(), child_type)) {
                return child;
            }
        }
        return null;
    }
};

/// Function information
pub const FunctionInfo = struct {
    name_node: Node,
    params_node: ?Node,
    body_node: ?Node,
    kind: FunctionKind,
};

pub const FunctionKind = enum {
    function,
    method,
    arrow,
};

/// Class information
pub const ClassInfo = struct {
    name_node: Node,
    body_node: ?Node,
};

/// Import information
pub const ImportInfo = struct {
    node: Node,
    kind: ImportKind,
};

pub const ImportKind = enum {
    source,
    default,
    named,
};

/// Variable information
pub const VariableInfo = struct {
    node: Node,
    kind: VariableKind,
};

pub const VariableKind = enum {
    declaration,
    usage,
};
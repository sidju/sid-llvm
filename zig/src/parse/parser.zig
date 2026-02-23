const std = @import("std");
const types = @import("types.zig");
const lexer_mod = @import("lexer.zig");

const ParseError = types.ParseError;
const Value = types.Value;
const Field = types.Field;
const Lexer = lexer_mod.Lexer;
const Token = lexer_mod.Token;
const TokenTag = lexer_mod.TokenTag;

const ContainerKind = enum {
    list,
    substack,
    script,
};

const BraceKind = enum {
    unknown,
    set,
    struct_lit,
};

const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    current: Token,

    fn init(allocator: std.mem.Allocator, source: []const u8) ParseError!Parser {
        var lexer = Lexer.init(source);
        const current = try lexer.nextToken();
        return .{
            .allocator = allocator,
            .lexer = lexer,
            .current = current,
        };
    }

    fn parseTopLevel(self: *Parser) ParseError![]Value {
        return self.parseSequence(null, false);
    }

    fn parseSequence(self: *Parser, terminator: ?TokenTag, forbid_invoke: bool) ParseError![]Value {
        var values: std.ArrayList(Value) = .empty;
        errdefer values.deinit(self.allocator);

        while (true) {
            if (terminator) |term| {
                if (self.current.tag == term) {
                    try self.advance();
                    break;
                }
                if (self.current.tag == .eof) return error.UnterminatedTemplate;
            } else if (self.current.tag == .eof) {
                break;
            }

            const next_value = try self.parseValue(forbid_invoke);
            try values.append(self.allocator, next_value);
        }

        return values.toOwnedSlice(self.allocator);
    }

    fn parseValue(self: *Parser, forbid_invoke: bool) ParseError!Value {
        const token = self.current;
        return switch (token.tag) {
            .number => try self.parseNumberToken(token.lexeme),
            .string_lit => blk: {
                try self.advance();
                break :blk .{ .string = token.lexeme };
            },
            .char_lit => blk: {
                try self.advance();
                break :blk .{ .char = token.lexeme };
            },
            .identifier => try self.parseIdentifierToken(token.lexeme),
            .parent_ref => try self.parseParentRefToken(token.lexeme),
            .bang => blk: {
                if (forbid_invoke) return error.InvokeForbidden;
                try self.advance();
                break :blk .{ .invoke = {} };
            },
            .l_bracket => self.parseContainer(.list, .r_bracket, forbid_invoke),
            .l_paren => self.parseContainer(.substack, .r_paren, forbid_invoke),
            .l_angle => self.parseContainer(.script, .r_angle, forbid_invoke),
            .l_brace => self.parseBrace(forbid_invoke),
            else => error.UnexpectedToken,
        };
    }

    fn parseContainer(
        self: *Parser,
        kind: ContainerKind,
        end_tag: TokenTag,
        forbid_invoke: bool,
    ) ParseError!Value {
        try self.advance(); // consume opener
        const items = try self.parseSequence(end_tag, forbid_invoke);
        return switch (kind) {
            .list => .{ .list = items },
            .substack => .{ .substack = items },
            .script => .{ .script = items },
        };
    }

    fn parseBrace(self: *Parser, forbid_invoke: bool) ParseError!Value {
        try self.advance(); // consume '{'

        var set_values: std.ArrayList(Value) = .empty;
        errdefer set_values.deinit(self.allocator);
        var fields: std.ArrayList(Field) = .empty;
        errdefer fields.deinit(self.allocator);

        var kind: BraceKind = .unknown;
        while (self.current.tag != .r_brace) {
            if (self.current.tag == .eof) return error.UnterminatedTemplate;

            const key_or_value = try self.parseValue(forbid_invoke);
            if (self.current.tag == .colon) {
                if (kind == .set) return error.UnexpectedToken;
                kind = .struct_lit;

                const key = switch (key_or_value) {
                    .label => |label| label,
                    .string => |label| label,
                    else => return error.UnexpectedToken,
                };

                try self.advance(); // consume ':'
                const field_value = try self.parseValue(forbid_invoke);
                try fields.append(self.allocator, .{
                    .key = key,
                    .value = field_value,
                });
            } else {
                if (kind == .struct_lit) return error.UnexpectedToken;
                kind = .set;
                try set_values.append(self.allocator, key_or_value);
            }
        }

        try self.advance(); // consume '}'
        return switch (kind) {
            .unknown, .set => .{ .set = try set_values.toOwnedSlice(self.allocator) },
            .struct_lit => .{ .struct_lit = try fields.toOwnedSlice(self.allocator) },
        };
    }

    fn parseIdentifierToken(self: *Parser, lexeme: []const u8) ParseError!Value {
        try self.advance();
        if (std.mem.eql(u8, lexeme, "true")) return .{ .bool = true };
        if (std.mem.eql(u8, lexeme, "false")) return .{ .bool = false };
        return .{ .label = lexeme };
    }

    fn parseParentRefToken(self: *Parser, lexeme: []const u8) ParseError!Value {
        try self.advance();
        var numeric = true;
        for (lexeme) |ch| {
            if (ch < '0' or ch > '9') {
                numeric = false;
                break;
            }
        }

        if (numeric) {
            const idx = std.fmt.parseInt(usize, lexeme, 10) catch return error.InvalidParentAccess;
            return .{ .parent_stack_move = idx };
        }
        return .{ .parent_label = lexeme };
    }

    fn parseNumberToken(self: *Parser, lexeme: []const u8) ParseError!Value {
        try self.advance();
        if (std.mem.indexOfScalar(u8, lexeme, '.')) |_| {
            const float_val = std.fmt.parseFloat(f64, lexeme) catch return error.InvalidNumber;
            return .{ .float = float_val };
        }

        const int_val = std.fmt.parseInt(i64, lexeme, 10) catch return error.InvalidNumber;
        return .{ .int = int_val };
    }

    fn advance(self: *Parser) ParseError!void {
        self.current = try self.lexer.nextToken();
    }
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8) ParseError![]Value {
    var parser = try Parser.init(allocator, source);
    return parser.parseTopLevel();
}

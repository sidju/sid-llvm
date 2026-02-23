const types = @import("types.zig");

pub const ParseError = types.ParseError;

pub const TokenTag = enum {
    eof,
    l_paren,
    r_paren,
    l_bracket,
    r_bracket,
    l_brace,
    r_brace,
    l_angle,
    r_angle,
    colon,
    bang,
    number,
    string_lit,
    char_lit,
    identifier,
    parent_ref,
};

pub const Token = struct {
    tag: TokenTag,
    lexeme: []const u8 = "",
};

pub const Lexer = struct {
    source: []const u8,
    index: usize,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .index = 0,
        };
    }

    pub fn nextToken(self: *Lexer) ParseError!Token {
        self.skipIgnorable();

        const ch = self.peekByte() orelse return .{ .tag = .eof };
        return switch (ch) {
            '(' => self.consumeSingle(.l_paren),
            ')' => self.consumeSingle(.r_paren),
            '[' => self.consumeSingle(.l_bracket),
            ']' => self.consumeSingle(.r_bracket),
            '{' => self.consumeSingle(.l_brace),
            '}' => self.consumeSingle(.r_brace),
            '<' => self.consumeSingle(.l_angle),
            '>' => self.consumeSingle(.r_angle),
            ':' => self.consumeSingle(.colon),
            '!' => self.consumeSingle(.bang),
            '"' => self.readString(),
            '\'' => self.readChar(),
            '$' => self.readParentRef(),
            else => if (isNumberStart(ch)) self.readNumber() else self.readIdentifier(),
        };
    }

    fn consumeSingle(self: *Lexer, tag: TokenTag) Token {
        self.index += 1;
        return .{ .tag = tag };
    }

    fn skipIgnorable(self: *Lexer) void {
        while (self.peekByte()) |ch| {
            switch (ch) {
                ' ', '\n', '\r', '\t', ',' => self.index += 1,
                '#' => {
                    self.index += 1;
                    while (self.peekByte()) |comment_ch| {
                        self.index += 1;
                        if (comment_ch == '\n') break;
                    }
                },
                else => return,
            }
        }
    }

    fn readString(self: *Lexer) ParseError!Token {
        self.index += 1; // opening quote
        const start = self.index;
        while (self.peekByte()) |ch| {
            if (ch == '"') {
                const out = self.source[start..self.index];
                self.index += 1; // closing quote
                return .{
                    .tag = .string_lit,
                    .lexeme = out,
                };
            }
            self.index += 1;
        }
        return error.UnterminatedString;
    }

    fn readChar(self: *Lexer) ParseError!Token {
        self.index += 1; // opening quote
        const start = self.index;
        while (self.peekByte()) |ch| {
            if (ch == '\'') {
                if (self.index == start) return error.InvalidChar;
                const out = self.source[start..self.index];
                self.index += 1; // closing quote
                return .{
                    .tag = .char_lit,
                    .lexeme = out,
                };
            }
            self.index += 1;
        }
        return error.UnterminatedChar;
    }

    fn readParentRef(self: *Lexer) ParseError!Token {
        self.index += 1; // $
        const start = self.index;
        while (self.peekByte()) |ch| {
            if (isWordDelimiter(ch)) break;
            self.index += 1;
        }
        if (self.index == start) return error.InvalidParentAccess;
        return .{
            .tag = .parent_ref,
            .lexeme = self.source[start..self.index],
        };
    }

    fn readNumber(self: *Lexer) Token {
        const start = self.index;
        self.index += 1;
        while (self.peekByte()) |ch| {
            if (isWordDelimiter(ch)) break;
            self.index += 1;
        }
        return .{
            .tag = .number,
            .lexeme = self.source[start..self.index],
        };
    }

    fn readIdentifier(self: *Lexer) Token {
        const start = self.index;
        self.index += 1;
        while (self.peekByte()) |ch| {
            if (isWordDelimiter(ch)) break;
            self.index += 1;
        }
        return .{
            .tag = .identifier,
            .lexeme = self.source[start..self.index],
        };
    }

    fn peekByte(self: *const Lexer) ?u8 {
        if (self.index >= self.source.len) return null;
        return self.source[self.index];
    }
};

fn isNumberStart(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '-' or ch == '.';
}

fn isWordDelimiter(ch: u8) bool {
    return switch (ch) {
        ' ', '\n', '\r', '\t', ',' => true,
        '#', '!', ':', '$' => true,
        '(', ')', '[', ']', '{', '}', '<', '>', '"', '\'' => true,
        else => false,
    };
}

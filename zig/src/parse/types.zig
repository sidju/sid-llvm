const std = @import("std");

pub const ParseError = error{
    OutOfMemory,
    UnexpectedToken,
    UnterminatedString,
    UnterminatedChar,
    InvalidChar,
    InvalidNumber,
    InvalidParentAccess,
    UnterminatedTemplate,
    InvokeForbidden,
};

pub const Field = struct {
    key: []const u8,
    value: Value,
};

pub const Value = union(enum) {
    invoke: void,
    bool: bool,
    int: i64,
    float: f64,
    string: []const u8,
    char: []const u8,
    label: []const u8,
    parent_stack_move: usize,
    parent_label: []const u8,
    list: []Value,
    set: []Value,
    struct_lit: []Field,
    substack: []Value,
    script: []Value,
};

pub fn freeValues(allocator: std.mem.Allocator, values: []Value) void {
    for (values) |value| freeValue(allocator, value);
    allocator.free(values);
}

fn freeValue(allocator: std.mem.Allocator, value: Value) void {
    switch (value) {
        .list => |inner| {
            freeValues(allocator, inner);
        },
        .set => |inner| {
            freeValues(allocator, inner);
        },
        .substack => |inner| {
            freeValues(allocator, inner);
        },
        .script => |inner| {
            freeValues(allocator, inner);
        },
        .struct_lit => |fields| {
            for (fields) |field| {
                freeValue(allocator, field.value);
            }
            allocator.free(fields);
        },
        else => {},
    }
}

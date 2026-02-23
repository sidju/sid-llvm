const std = @import("std");
const types = @import("types.zig");
const parser = @import("parser.zig");

pub const ParseError = types.ParseError;
pub const Field = types.Field;
pub const Value = types.Value;
pub const freeValues = types.freeValues;
pub const parse = parser.parse;

test "invoke is parsed as standalone value" {
    const parsed = try parse(std.testing.allocator, "print!");
    defer freeValues(std.testing.allocator, parsed);

    try std.testing.expectEqual(@as(usize, 2), parsed.len);
    try std.testing.expectEqualStrings("print", parsed[0].label);
    try std.testing.expect(std.meta.activeTag(parsed[1]) == .invoke);
}

test "list and nested substack parse correctly" {
    const parsed = try parse(std.testing.allocator, "[1 \"two\" (true !)]");
    defer freeValues(std.testing.allocator, parsed);

    try std.testing.expectEqual(@as(usize, 1), parsed.len);
    const list = parsed[0].list;
    try std.testing.expectEqual(@as(usize, 3), list.len);
    try std.testing.expectEqual(@as(i64, 1), list[0].int);
    try std.testing.expectEqualStrings("two", list[1].string);

    const substack = list[2].substack;
    try std.testing.expectEqual(@as(usize, 2), substack.len);
    try std.testing.expectEqual(true, substack[0].bool);
    try std.testing.expect(std.meta.activeTag(substack[1]) == .invoke);
}

test "brace chooses set without top-level colon" {
    const parsed = try parse(std.testing.allocator, "{1, \"two\", 3}");
    defer freeValues(std.testing.allocator, parsed);

    try std.testing.expectEqual(@as(usize, 1), parsed.len);
    const values = parsed[0].set;
    try std.testing.expectEqual(@as(usize, 3), values.len);
    try std.testing.expectEqual(@as(i64, 1), values[0].int);
    try std.testing.expectEqualStrings("two", values[1].string);
    try std.testing.expectEqual(@as(i64, 3), values[2].int);
}

test "brace chooses struct with top-level colon" {
    const parsed = try parse(std.testing.allocator, "{one: 1, two: 2}");
    defer freeValues(std.testing.allocator, parsed);

    try std.testing.expectEqual(@as(usize, 1), parsed.len);
    const fields = parsed[0].struct_lit;
    try std.testing.expectEqual(@as(usize, 2), fields.len);
    try std.testing.expectEqualStrings("one", fields[0].key);
    try std.testing.expectEqual(@as(i64, 1), fields[0].value.int);
    try std.testing.expectEqualStrings("two", fields[1].key);
    try std.testing.expectEqual(@as(i64, 2), fields[1].value.int);
}

test "parent substitutions parse as dedicated values" {
    const parsed = try parse(std.testing.allocator, "($2 $name)");
    defer freeValues(std.testing.allocator, parsed);

    try std.testing.expectEqual(@as(usize, 1), parsed.len);
    const values = parsed[0].substack;
    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqual(@as(usize, 2), values[0].parent_stack_move);
    try std.testing.expectEqualStrings("name", values[1].parent_label);
}

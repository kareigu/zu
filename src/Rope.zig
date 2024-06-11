const std = @import("std");
const Self = @This();
const Error = error{
    InvalidIndex,
};

const Branch = struct {
    left: ?*Self,
    right: ?*Self,
};

const Data = union(enum) {
    text: []const u8,
    branch: Branch,
};

const ROPE_TEXT_LENGTH = if (@import("builtin").is_test) 8 else 256;

data: Data,
len: usize,

pub fn init(alloc: std.mem.Allocator, text: []const u8) !*Self {
    if (text.len <= ROPE_TEXT_LENGTH) {
        return Self.create_text_rope(alloc, text);
    }

    var chunk_count = text.len / ROPE_TEXT_LENGTH;
    if (text.len % ROPE_TEXT_LENGTH > 0) {
        chunk_count += 1;
    }

    var left_parent = try Self.create_branch_rope(alloc, null, null);
    var right_parent: ?*Self = null;

    for (0..chunk_count) |chunk_index| {
        const start_offset = chunk_index * ROPE_TEXT_LENGTH;
        const end_offset = if (start_offset + ROPE_TEXT_LENGTH > text.len) text.len else start_offset + ROPE_TEXT_LENGTH;
        const chunk = text[start_offset..end_offset];

        const text_rope = try Self.create_text_rope(alloc, chunk);

        if (left_parent.data.branch.left == null) {
            left_parent.set_left_branch(text_rope);
            continue;
        }

        if (left_parent.data.branch.right == null) {
            left_parent.set_right_branch(text_rope);
            continue;
        }

        if (right_parent) |right| {
            if (right.data.branch.left == null) {
                right.set_left_branch(text_rope);
                continue;
            }
            if (right.data.branch.right == null) {
                right.set_right_branch(text_rope);
                continue;
            }

            left_parent = try Self.create_branch_rope(alloc, left_parent, right_parent);
        }

        right_parent = try Self.create_branch_rope(alloc, text_rope, null);
    }

    if (right_parent) |right| {
        return try Self.create_branch_rope(alloc, left_parent, right);
    }

    return left_parent;
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    switch (self.data) {
        .text => {},
        .branch => |branch| {
            if (branch.left) |left| {
                left.deinit(alloc);
            }

            if (branch.right) |right| {
                right.deinit(alloc);
            }
        },
    }
    alloc.destroy(self);
}

pub fn create_text_rope(alloc: std.mem.Allocator, text: []const u8) !*Self {
    var self = try alloc.create(Self);
    self.data.text = text;
    self.len = text.len;

    return self;
}

pub fn create_branch_rope(alloc: std.mem.Allocator, left: ?*Self, right: ?*Self) !*Self {
    var self = try alloc.create(Self);
    self.data = .{ .branch = .{ .left = left, .right = right } };

    var total_len: usize = 0;
    if (left) |l| {
        total_len += l.total_length();
    }

    self.len = total_len;

    return self;
}

pub fn set_left_branch(self: *Self, left: *Self) void {
    std.debug.assert(self.data == Data.branch);
    self.data.branch.left = left;
    self.len = left.total_length();
}

pub fn set_right_branch(self: *Self, right: *Self) void {
    std.debug.assert(self.data == Data.branch);
    self.data.branch.right = right;
}

pub fn total_length(self: *const Self) usize {
    const total_len: usize = self.len;

    return switch (self.data) {
        .text => total_len,
        .branch => |b| {
            if (b.right) |r|
                return total_len + r.total_length();
            return total_len;
        },
    };
}

pub fn push_str(self: *Self, alloc: std.mem.Allocator, str: []const u8) !*Self {
    const push_rope = try Self.init(alloc, str);
    if (self.data == Data.text) {
        return try Self.create_branch_rope(alloc, self, push_rope);
    }

    if (self.data.branch.left == null) {
        self.data.branch.left = push_rope;
        return self;
    }

    if (self.data.branch.right == null) {
        self.data.branch.right = push_rope;
        return self;
    }

    const right_rope = try Self.create_branch_rope(alloc, push_rope, null);
    const parent_rope = try Self.create_branch_rope(alloc, self, right_rope);
    return parent_rope;
}

pub fn get_char(self: *const Self, index: usize) Error!u8 {
    if (self.data == Data.text) {
        if (index > self.data.text.len - 1) {
            return error.InvalidIndex;
        }
        return self.data.text[index];
    }

    if (index > self.len - 1) {
        if (self.data.branch.right) |right| {
            return right.get_char(index - self.len);
        }
        return error.InvalidIndex;
    }

    if (self.data.branch.left) |left| {
        return left.get_char(index);
    }

    return error.InvalidIndex;
}

test "Rope.length() with a single branch" {
    const alloc = std.testing.allocator;
    const rope_left = try Self.create_text_rope(alloc, "test_left");
    defer alloc.destroy(rope_left);
    const rope_right = try Self.create_text_rope(alloc, "test_right");
    defer alloc.destroy(rope_right);
    const rope_branch = try Self.create_branch_rope(alloc, rope_left, rope_right);
    defer alloc.destroy(rope_branch);

    const real_len = rope_left.len + rope_right.len;
    try std.testing.expectEqual(real_len, rope_branch.total_length());
}

test "Rope.length() with 2 branches" {
    const alloc = std.testing.allocator;
    const rope_left = try Self.create_text_rope(alloc, "test_left");
    defer alloc.destroy(rope_left);
    const rope_right = try Self.create_text_rope(alloc, "test_right");
    defer alloc.destroy(rope_right);
    const rope_branch1 = try Self.create_branch_rope(alloc, rope_left, rope_right);
    defer alloc.destroy(rope_branch1);
    const rope_branch2 = try Self.create_branch_rope(alloc, rope_branch1, null);
    defer alloc.destroy(rope_branch2);

    const real_len = rope_left.len + rope_right.len;
    try std.testing.expectEqual(real_len, rope_branch2.total_length());
}

test "Rope.length() with 3 branches" {
    const alloc = std.testing.allocator;
    const rope_left = try Self.create_text_rope(alloc, "test_left");
    defer alloc.destroy(rope_left);
    const rope_right = try Self.create_text_rope(alloc, "test_right");
    defer alloc.destroy(rope_right);
    const rope_branch1 = try Self.create_branch_rope(alloc, rope_left, rope_right);
    defer alloc.destroy(rope_branch1);

    const rope_branch_left = try Self.create_text_rope(alloc, "test_branch_left");
    defer alloc.destroy(rope_branch_left);
    const rope_branch_right = try Self.create_text_rope(alloc, "test_branch_right");
    defer alloc.destroy(rope_branch_right);
    const rope_branch2 = try Self.create_branch_rope(alloc, rope_branch_left, rope_branch_right);
    defer alloc.destroy(rope_branch2);

    const rope_branch3 = try Self.create_branch_rope(alloc, rope_branch1, rope_branch2);
    defer alloc.destroy(rope_branch3);

    const rope_root = try Self.create_branch_rope(alloc, rope_branch3, null);
    defer alloc.destroy(rope_root);

    const real_len = rope_left.len + rope_right.len + rope_branch_right.len + rope_branch_left.len;
    try std.testing.expectEqual(real_len, rope_root.total_length());
}

test "Rope.init() under max single rope length" {
    const alloc = std.testing.allocator;
    const text = "1234567";
    const rope = try Self.init(alloc, text);
    defer rope.deinit(alloc);

    const expected = Self{ .data = .{ .text = text }, .len = 7 };
    try std.testing.expectEqual(expected, rope.*);
}

test "Rope.init() over max single rope length" {
    const alloc = std.testing.allocator;
    const text = "1234567891011";
    const rope = try Self.init(alloc, text);
    defer rope.deinit(alloc);

    try std.testing.expectEqual(8, rope.data.branch.left.?.len);
    try std.testing.expectEqualStrings(text[0..8], rope.data.branch.left.?.data.text);
    try std.testing.expectEqual(5, rope.data.branch.right.?.len);
    try std.testing.expectEqualStrings(text[8..], rope.data.branch.right.?.data.text);
    try std.testing.expectEqual(13, rope.total_length());
}

test "Rope.init() over max single rope multiple times" {
    const alloc = std.testing.allocator;
    const text = "123456789101112231415161718192021222324252627282930";
    const rope = try Self.init(alloc, text);
    defer rope.deinit(alloc);

    try std.testing.expectEqual(text.len, rope.total_length());
    const data1 = rope.data.branch.left.?.data.branch.left.?.data.branch.left.?.data.branch.left.?.data.text;
    try std.testing.expectEqualStrings(text[0..8], data1);
    const data2 = rope.data.branch.right.?.data.branch.left.?.data.text;
    try std.testing.expectEqualStrings(text[48..], data2);
}

test "Rope.push_str() push under max single rope length" {
    const alloc = std.testing.allocator;
    const text = "1234567";

    var rope = try Self.init(alloc, text);
    defer rope.deinit(alloc);

    rope = try rope.push_str(alloc, text);

    try std.testing.expectEqual(text.len * 2, rope.total_length());
    try std.testing.expectEqualStrings(text, rope.data.branch.left.?.data.text);
    try std.testing.expectEqualStrings(text, rope.data.branch.right.?.data.text);
}

test "Rope.push_str() push over max single rope length" {
    const alloc = std.testing.allocator;
    const text_base = "1234567";
    const text_push = "1234567891011";

    var rope = try Self.init(alloc, text_base);
    defer rope.deinit(alloc);

    rope = try rope.push_str(alloc, text_push);

    try std.testing.expectEqual(text_base.len + text_push.len, rope.total_length());
    try std.testing.expectEqualStrings(text_base, rope.data.branch.left.?.data.text);
    try std.testing.expectEqualStrings(text_push[0..8], rope.data.branch.right.?.data.branch.left.?.data.text);
    try std.testing.expectEqualStrings(text_push[8..], rope.data.branch.right.?.data.branch.right.?.data.text);
}

test "Rope.get_char()" {
    const alloc = std.testing.allocator;
    const text = "1234567";

    const text_rope = try Self.create_text_rope(alloc, text);
    defer text_rope.deinit(alloc);

    const char = try text_rope.get_char(2);
    try std.testing.expectEqual('3', char);

    const rope = try Self.init(alloc, text ++ text);
    defer rope.deinit(alloc);

    const char2 = try rope.get_char(5);
    try std.testing.expectEqual('6', char2);

    const char3 = try rope.get_char(9);
    try std.testing.expectEqual('3', char3);
}

test "Rope.get_char() errors" {
    const alloc = std.testing.allocator;
    const text = "1234";

    var rope = try Self.init(alloc, text);
    try std.testing.expectError(Error.InvalidIndex, rope.get_char(5));
    rope.deinit(alloc);

    rope = try Self.init(alloc, text ++ text ++ text ++ text);
    try std.testing.expectError(Error.InvalidIndex, rope.get_char(25));
    rope.deinit(alloc);
}

test "Rope.get_char() border character" {
    const alloc = std.testing.allocator;
    const text = "123456789";

    const rope = try Self.init(alloc, text);
    defer rope.deinit(alloc);

    try std.testing.expectEqual('9', rope.get_char(8));
}


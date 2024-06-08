const std = @import("std");
const Self = @This();

const Branch = struct {
    left: ?*Self,
    right: ?*Self,
};

const Data = union(enum) {
    text: []const u8,
    branch: Branch,
};

data: Data,
len: usize,

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

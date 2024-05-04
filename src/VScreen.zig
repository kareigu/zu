const std = @import("std");
const io = std.io;

const Self = @This();
const Error = error{
    BufferLimitReached,
};
const CursorPos = struct {
    x: u32,
    y: u32,
};

const BUFFER_SIZE = 16 * 1024;

buffer: []u8,
idx: usize = 0,
cursor_pos: CursorPos = .{ .x = 1, .y = 1 },

pub fn init(alloc: std.mem.Allocator) !Self {
    return .{ .buffer = try alloc.alloc(u8, BUFFER_SIZE) };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) !void {
    alloc.free(self.buffer);
}

pub fn screen_buffer(self: *Self) []const u8 {
    return self.buffer[0..self.idx];
}

pub fn move_cursor(self: *Self, amount: [2]i4) void {
    const x = @as(i64, @intCast(self.cursor_pos.x)) -| amount[0];
    const y = @as(i64, @intCast(self.cursor_pos.y)) -| amount[1];
    self.cursor_pos.x = if (x > 1) @intCast(x) else 1;
    self.cursor_pos.y = if (y > 1) @intCast(y) else 1;
}

pub fn write_bytes(self: *Self, bytes: []const u8) !void {
    for (bytes) |byte| {
        self.idx += 1;
        if (self.idx > self.buffer.len) {
            return Error.BufferLimitReached;
        }
        self.buffer[self.idx] = byte;
    }
}

pub fn write_byte(self: *Self, byte: u8) !void {
    var buf = [_]u8{0} ** 4;
    const wrote = try std.fmt.bufPrint(&buf, "{d}", .{byte});

    for (wrote) |b| {
        self.idx += 1;
        if (self.idx > self.buffer.len) {
            return Error.BufferLimitReached;
        }
        self.buffer[self.idx] = b;
    }
}

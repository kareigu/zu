const std = @import("std");
const io = std.io;

const Self = @This();
const Error = error{
    BufferLimitReached,
};

const BUFFER_SIZE = 16 * 1024;

buffer: []u8,
idx: usize = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    return .{ .buffer = try alloc.alloc(u8, BUFFER_SIZE) };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) !void {
    alloc.free(self.buffer);
}

pub fn screen_buffer(self: *Self) []const u8 {
    return self.buffer[0..self.idx];
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

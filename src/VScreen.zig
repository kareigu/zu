const std = @import("std");
const io = std.io;

const Self = @This();
const Error = error{
    BufferLimitReached,
};
const StdOut = @TypeOf(io.getStdOut().writer());

const BUFFER_SIZE = 16 * 1024;

buffer: []u8,
idx: usize = 0,

pub fn init(alloc: std.mem.Allocator, stdout: *StdOut) !Self {
    try stdout.writeAll("\x1b[?1049h");

    return .{ .buffer = try alloc.alloc(u8, BUFFER_SIZE) };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator, stdout: *StdOut) !void {
    try stdout.writeAll("\x1b[?1049l");
    alloc.free(self.buffer);
}

pub fn write_out(self: *Self, stdout: *StdOut) !void {
    const to_write = self.buffer[0..self.idx];
    try stdout.writeAll(to_write);
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

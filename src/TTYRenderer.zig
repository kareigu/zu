const std = @import("std");
const io = std.io;
const c_ioctl = @cImport(@cInclude("sys/ioctl.h"));
const Renderer = @import("Renderer.zig");
const VScreen = @import("VScreen.zig");

const StdOut = @TypeOf(io.getStdOut().writer());
const Self = @This();
pub const Error = error{
    FailedGettingWindowSize,
};

stdout: StdOut,
window_size: Renderer.WindowSize,

pub fn init() !Self {
    const stdout = io.getStdOut().writer();
    try stdout.writeAll("\x1b[?1049h");
    return .{ .stdout = stdout, .window_size = try window_size(&stdout) };
}

pub fn deinit(self: *Self) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var buffer = std.ArrayList(u8).init(arena.allocator());
    defer buffer.deinit();
    try self.clear_screen(.{&buffer});
    try buffer.appendSlice("\x1b[?1049l");
    try self.stdout.writeAll(buffer.items);
}

pub fn out(self: *Self) *StdOut {
    return &self.stdout;
}

pub fn refresh_screen(self: *Self, vscreen: *VScreen) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var buffer = std.ArrayList(u8).init(arena.allocator());
    defer buffer.deinit();

    try buffer.appendSlice("\x1b[?25l");
    try buffer.appendSlice("\x1b[H");

    for (0..self.window_size.height) |i| {
        try buffer.append('~');

        try buffer.appendSlice("\x1b[K");
        if (i < self.window_size.height - 1) {
            try buffer.appendSlice("\r\n");
        }
    }

    try buffer.appendSlice("\x1b[H");

    try buffer.appendSlice(vscreen.screen_buffer());

    var cursor_pos_buf = [_]u8{0} ** 32;
    const cursor_pos = try std.fmt.bufPrint(&cursor_pos_buf, "\x1b[{d};{d}H", .{ vscreen.cursor_pos.y, vscreen.cursor_pos.x });
    try buffer.appendSlice(cursor_pos);

    try buffer.appendSlice("\x1b[?25h");

    _ = try self.stdout.write(buffer.items);
}

pub fn clear_screen(self: *Self, buffer: anytype) !void {
    const type_info = @typeInfo(@TypeOf(buffer));
    const s = switch (type_info) {
        .Struct => |s| s,
        else => @compileError("buffer should be contained in a struct"),
    };

    if (s.fields.len == 0) {
        _ = try self.stdout.write("\x1b[2J");
        _ = try self.stdout.write("\x1b[H");
        return;
    }

    if (s.fields.len > 1) {
        @compileError("only buffer should be provided");
    }
    var b = switch (s.fields[0].type) {
        *std.ArrayList(u8) => buffer[0],
        else => @compileError("buffer should be a ArrayList(u8)"),
    };
    try b.appendSlice("\x1b[2J");
    try b.appendSlice("\x1b[H");
}

fn window_size(stdout: *const StdOut) !Renderer.WindowSize {
    var window_s = c_ioctl.winsize{};

    if (c_ioctl.ioctl(stdout.*.context.handle, c_ioctl.TIOCGWINSZ, &window_s) != 0) {
        return Error.FailedGettingWindowSize;
    }

    return .{ .width = window_s.ws_col, .height = window_s.ws_row };
}

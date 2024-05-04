const std = @import("std");
const io = std.io;
const c_ioctl = @cImport(@cInclude("sys/ioctl.h"));
const Renderer = @import("Renderer.zig");

const StdOut = @TypeOf(io.getStdOut().writer());
const Self = @This();
pub const Error = error{
    FailedGettingWindowSize,
};

stdout: StdOut,
window_size: Renderer.WindowSize,

pub fn init() !Self {
    const stdout = io.getStdOut().writer();
    return .{ .stdout = stdout, .window_size = try window_size(&stdout) };
}

pub fn out(self: *Self) *StdOut {
    return &self.stdout;
}

pub fn refresh_screen(self: *Self) !void {
    try self.clear_screen();
    for (0..self.window_size.height) |i| {
        try self.stdout.writeByte('~');

        if (i < self.window_size.height - 1) {
            _ = try self.stdout.write("\r\n");
        }
    }
    _ = try self.stdout.write("\x1b[H");
}

pub fn clear_screen(self: *Self) !void {
    _ = try self.stdout.write("\x1b[2J");
    _ = try self.stdout.write("\x1b[H");
}

fn window_size(stdout: *const StdOut) !Renderer.WindowSize {
    var window_s = c_ioctl.winsize{};

    if (c_ioctl.ioctl(stdout.*.context.handle, c_ioctl.TIOCGWINSZ, &window_s) != 0) {
        return Error.FailedGettingWindowSize;
    }

    return .{ .width = window_s.ws_col, .height = window_s.ws_row };
}

const std = @import("std");
const Input = @import("Input.zig");
const VScreen = @import("VScreen.zig");

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();
    var stderr = std.io.getStdErr().writer();
    var stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(std.heap.GeneralPurposeAllocatorConfig{}){};
    defer switch (gpa.deinit()) {
        .ok => undefined,
        .leak => stderr.writeAll("leaked memory detected"),
    } catch unreachable;
    const alloc = gpa.allocator();

    var vscreen = try VScreen.init(alloc, &stdout);
    defer vscreen.deinit(alloc, &stdout) catch unreachable;

    var input = try Input.init(&stdin);
    defer input.deinit() catch unreachable;

    while (true) {
        try switch (try input.process()) {
            .none => continue,
            .quit => break,
            .char => |char| {
                try vscreen.write_bytes(&char);
                try vscreen.write_out(&stdout);
            },
            .ctrl => |ctrl| std.fmt.format(stdout, "{d}", .{ctrl}),
        };
    }
}

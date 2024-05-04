const std = @import("std");
const Input = @import("Input.zig");
const VScreen = @import("VScreen.zig");
const TTYRenderer = @import("TTYRenderer.zig");

pub fn main() !void {
    var renderer = try TTYRenderer.init();
    var stderr = std.io.getStdErr().writer();
    var stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(std.heap.GeneralPurposeAllocatorConfig{}){};
    defer switch (gpa.deinit()) {
        .ok => undefined,
        .leak => stderr.writeAll("leaked memory detected"),
    } catch unreachable;
    const alloc = gpa.allocator();

    var vscreen = try VScreen.init(alloc, renderer.out());
    defer vscreen.deinit(alloc, renderer.out()) catch unreachable;

    var input = try Input.init(&stdin);
    defer input.deinit() catch unreachable;

    defer renderer.clear_screen(.{}) catch unreachable;
    while (true) {
        try renderer.refresh_screen();
        try vscreen.write_out(renderer.out());
        switch (try input.process()) {
            .none => continue,
            .quit => break,
            .char => |char| try vscreen.write_bytes(&char),
            .ctrl => |ctrl| try vscreen.write_byte(ctrl),
        }
    }
}

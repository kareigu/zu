const std = @import("std");
const Input = @import("Input.zig");
const VScreen = @import("VScreen.zig");
const TTYRenderer = @import("TTYRenderer.zig");
const constants = @import("constants");

const title_prompt = std.fmt.comptimePrint("zu - {}\r\n", .{constants.version});

pub fn main() !void {
    var renderer = try TTYRenderer.init();
    defer renderer.deinit() catch unreachable;
    var stderr = std.io.getStdErr().writer();
    var stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(std.heap.GeneralPurposeAllocatorConfig{}){};
    defer switch (gpa.deinit()) {
        .ok => undefined,
        .leak => stderr.writeAll("leaked memory detected"),
    } catch unreachable;
    const alloc = gpa.allocator();

    var vscreen = try VScreen.init(alloc);
    defer vscreen.deinit(alloc) catch unreachable;

    try vscreen.write_bytes(title_prompt);

    var input = try Input.init(&stdin);
    defer input.deinit() catch unreachable;

    while (true) {
        try renderer.refresh_screen(vscreen.screen_buffer());
        switch (try input.process()) {
            .none => continue,
            .quit => break,
            .char => |char| try vscreen.write_bytes(&char),
            .ctrl => |ctrl| try vscreen.write_byte(ctrl),
        }
    }
}

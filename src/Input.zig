const std = @import("std");
const io = std.io;
const c_term = @cImport(@cInclude("termios.h"));

const Self = @This();
const Error = error{
    InitFailed,
    InputReadError,
};

const StdIn = @TypeOf(io.getStdOut().reader());

const CRTL_START_CHAR = '\x1b';

stdin: *StdIn,
orig_termios: c_term.termios,

pub fn init(stdin: *StdIn) !Self {
    var termios = c_term.termios{};
    if (c_term.tcgetattr(stdin.*.context.handle, &termios) != 0) {
        return Error.InitFailed;
    }
    const orig_termios = termios;
    termios.c_iflag &= ~@as(c_ulong, c_term.IXON | c_term.ICRNL | c_term.BRKINT | c_term.INPCK | c_term.ISTRIP);
    termios.c_oflag &= ~@as(c_ulong, c_term.OPOST);
    termios.c_cflag &= ~@as(c_ulong, c_term.CS8);
    termios.c_lflag &= ~@as(c_ulong, c_term.ECHO | c_term.ICANON | c_term.ISIG | c_term.IEXTEN);
    termios.c_cc[c_term.VMIN] = 0;
    termios.c_cc[c_term.VTIME] = 1;
    if (c_term.tcsetattr(stdin.*.context.handle, c_term.TCSAFLUSH, &termios) != 0) {
        return Error.InitFailed;
    }

    return .{ .stdin = stdin, .orig_termios = orig_termios };
}

pub fn deinit(self: *Self) !void {
    if (c_term.tcsetattr(self.stdin.context.handle, c_term.TCSAFLUSH, &self.orig_termios) != 0) {
        return Error.InitFailed;
    }
}

const InputAction = union(enum) {
    char: [4]u8,
    ctrl: u8,
    move: [2]i4,
    quit,
    none,
};

pub fn process(self: *Self) !InputAction {
    const byte = self.stdin.readByte() catch |e| switch (e) {
        error.EndOfStream => return InputAction.none,
        else => return Error.InputReadError,
    };
    if (byte == 'q') {
        return InputAction.quit;
    }

    if (byte == CRTL_START_CHAR) {
        return self.process_control();
    }

    if (byte == 13) {
        return .{ .char = [4]u8{ '\r', '\n', 0, 0 } };
    }

    if (byte == 'h') {
        return .{ .move = .{ 1, 0 } };
    }
    if (byte == 'l') {
        return .{ .move = .{ -1, 0 } };
    }
    if (byte == 'j') {
        return .{ .move = .{ 0, -1 } };
    }
    if (byte == 'k') {
        return .{ .move = .{ 0, 1 } };
    }

    if (byte > 31 and byte < 128) {
        return .{ .char = [4]u8{ byte, 0, 0, 0 } };
    }

    return .{ .ctrl = byte };
}

fn process_control(self: *Self) !InputAction {
    const byte = for (0..2) |_| {
        const v = self.stdin.readByte() catch |e| switch (e) {
            error.EndOfStream => return InputAction.none,
            else => return Error.InputReadError,
        };
        if (v == '[') {
            continue;
        }
        break v;
    } else return InputAction.none;

    return switch (byte) {
        'A' => .{ .move = .{ 0, 1 } },
        'B' => .{ .move = .{ 0, -1 } },
        'C' => .{ .move = .{ -1, 0 } },
        'D' => .{ .move = .{ 1, 0 } },
        else => .{ .ctrl = byte },
    };
}

const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("stdlib.h");
    switch (builtin.os.tag) {
        .linux => {
            @cInclude("termios.h");
            @cInclude("unistd.h");
            @cInclude("sys/ioctl.h");
        },
        .windows => {
            @cInclude("windows.h");
            @cInclude("conio.h");
        },
        else => @compileError("Unsupported OS"),
    }
});

const PlatformSpecific = if (builtin.os.tag == .windows) struct {
    hwnd: c.HWND = null,
} else if (builtin.os.tag == .linux) struct {
    var originalTermios: c.struct_termios = undefined;
} else struct {};

var platform_specifc: PlatformSpecific = .{};

// implementation of getch and write for linux terminal

pub fn init() void {
    if (builtin.os.tag == .windows) {
        _ = c.system(""); // Poorly documented tick: Enable VT100 Windows mode.
    }
    if (builtin.os.tag == .linux) {
        if (c.tcgetattr(std.os.linux.STDIN_FILENO, &platform_specifc.originalTermios) < 0) {
            std.debug.print("could not get terminal settings\n", .{});
            std.process.exit(1);
        }

        var raw: c.struct_termios = platform_specifc.originalTermios;

        // raw mode
        raw.c_iflag &= ~@as(c_uint, c.BRKINT | c.ICRNL | c.INPCK | c.ISTRIP | c.IXON);
        raw.c_lflag &= ~@as(c_uint, c.ECHO | c.ICANON | c.IEXTEN | c.ISIG);

        // non-blocking reads
        raw.c_cc[c.VMIN] = 0;
        raw.c_cc[c.VTIME] = 0; //  // 0.1s timeout

        if (c.tcsetattr(std.os.linux.STDIN_FILENO, c.TCSANOW, &raw) < 0) {
            std.debug.print("could not set new terminal settings\n", .{});
            std.process.exit(1);
        }

        _ = c.atexit(cleanup_terminal);
    }
}

fn cleanup_terminal() callconv(.C) void {
    if (builtin.os.tag == .linux) {
        _ = c.tcsetattr(std.os.linux.STDIN_FILENO, c.TCSANOW, &platform_specifc.originalTermios);
    }
    std.debug.print("\nFinished\n", .{});
}

pub fn getch() ?u8 {
    if (builtin.os.tag == .windows) {
        const hit = c._kbhit();
        if (hit == 0) {
            return null;
        }
        const ch = c._getch();
        return @truncate(@as(u32, @intCast(ch)));
    } else if (builtin.os.tag == .linux) {
        var b: u8 = undefined;
        const count = c.read(std.os.linux.STDIN_FILENO, &b, 1);
        if (count == 0) {
            return null;
        }
        return b;
    } else {
        return null;
    }
}

pub fn write(buf: []const u8) !void {
    if (builtin.os.tag == .windows) {
        for (buf) |value| {
            _ = c._putch(value);
        }
    }
    if (builtin.os.tag == .linux) {
        const count = c.write(std.os.linux.STDOUT_FILENO, @as(*const anyopaque, @ptrCast(buf.ptr)), buf.len);
        if (count < buf.len) {
            std.debug.print("\nTBD, implement write retries\n", .{});
        }
    }
}

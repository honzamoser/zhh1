const std = @import("std");
const Io = std.Io;

const zhh1 = @import("zhh1");

const intro = @embedFile("./splash");

var terminal_width: usize = 0;
var terminal_height: usize = 0;

pub fn main(init: std.process.Init) !void {
    var buf: std.posix.winsize = undefined;
    try switch (std.posix.errno(
        std.posix.system.ioctl(
            std.Io.File.stdout().handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&buf),
        ),
    )) {
        .SUCCESS => {
            terminal_width = buf.col;
            terminal_height = buf.row;
        },
        else => error.IoctlError,
    };

    // _ = init;

    var buffer: [1024]u8 = undefined;
    var buffered = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const interface = &buffered.interface;

    try print_title(interface, init.gpa);
}

fn print_title(interface: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    try interface.writeAll("\x1b[0m\x1b[1m");

    var iter = std.mem.splitAny(u8, intro, "\n");
    const title_offset = offset(terminal_width, iter.peek().?.len, allocator);

    var i: u16 = 0;
    while (iter.next()) |l| {
        try interface.print("\x1b[{d}m{s}{s}\n", .{ (31 + i % 4), title_offset, l });
        i += 1;
    }

    allocator.free(title_offset);

    try interface.flush();
}

inline fn offset(width: usize, content_size: usize, allocator: std.mem.Allocator) []const u8 {
    if (allocator.alloc(u8, width / 2 - content_size / 2)) |buf| {
        @memset(buf, 0x20);
        return buf;
    } else |e| {
        std.debug.print("{}", .{e});
        @panic("Out of memory");
    }
}

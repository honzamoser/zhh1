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

    const stdin_fd = std.Io.File.stdin().handle;
    const termios_save = try std.posix.tcgetattr(stdin_fd);
    var input_mode = termios_save;
    input_mode.lflag.ICANON = false;
    input_mode.lflag.ECHO = false;
    try std.posix.tcsetattr(stdin_fd, .NOW, input_mode);

    defer {
        std.posix.tcsetattr(stdin_fd, .NOW, termios_save) catch {
            std.debug.print("Failed to reset terminal\n", .{});
        };
    }

    // _ = init;

    var buffer: [1024]u8 = undefined;
    var buffered = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const stdout_interface = &buffered.interface;

    try print_title(stdout_interface, init.gpa);

    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    const stdin_interface = &stdin.interface;

    const terminal_size = try get_terminal_size(stdout_interface, stdin_interface);

    std.debug.print("Terminal size is {d}x{d}\n", .{ terminal_size[0], terminal_size[1] });
}

fn get_terminal_size(writer_interface: *std.Io.Writer, reader_interface: *std.Io.Reader) ![2]u16 {
    try writer_interface.writeAll("\x1b[6n");
    try writer_interface.flush();
    const x = try reader_interface.takeDelimiterExclusive('R');

    const coordinates = x[2..];

    var split = std.mem.splitAny(u8, coordinates, &[_]u8{';'});

    var out: [2]u16 = undefined;

    var i: u16 = 0;
    while (split.next()) |num| {
        std.debug.print("{s}\n", .{num});
        out[i] = std.fmt.parseInt(u16, num, 10) catch 0;
        i += 1;
    }
    return out;
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

    // try interface.flush();
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

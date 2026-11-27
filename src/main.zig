const std = @import("std");
const Io = std.Io;

const zhh1 = @import("zhh1");

const intro = @embedFile("./splash");

var terminal_width: usize = 0;
var terminal_height: usize = 0;

const MenuReturnState = enum { Play, Options };

pub fn main(init: std.process.Init) !void {
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

    const terminal_size = try get_terminal_size();
    terminal_width = terminal_size[0];
    terminal_height = terminal_size[1];

    // _ = init;

    var buffer: [1024]u8 = undefined;
    var buffered = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const stdout_interface = &buffered.interface;

    try print_title(stdout_interface, init.arena.allocator());

    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    const stdin_interface = &stdin.interface;
    // _ = stdin_interface;

    // std.debug.print("Terminal size is {d}x{d}\n", .{ terminal_width, terminal_height });

    while (true) {
        try program_loop(stdin_interface, stdout_interface, init);
    }
}

fn program_loop(stdin: *std.Io.Reader, stdout: *std.Io.Writer, init: std.process.Init) !void {
    const menu_selection: MenuReturnState = try menu_loop(stdin, stdout, init.arena.allocator());

    switch (menu_selection) {
        .Play => {
            try stdout.writeAll("\x1b[2J");
            try game_loop(stdin, stdout, init.arena.allocator());
        },
        .Options => {},
    }
}

fn game_loop(stdin: *std.Io.Reader, stdout: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    _ = stdin;
    _ = allocator;
    try stdout.writeAll("gqame mode!!!");
    try stdout.flush();

    while (true) {}
}

fn menu_loop(stdin: *std.Io.Reader, stdout: *std.Io.Writer, allocator: std.mem.Allocator) !MenuReturnState {
    const start_text = "1. Start game";
    const start_offset = offset(terminal_width, start_text.len, allocator);

    const settings_text = "2. Options";
    const settings_offset = offset(terminal_width, settings_text.len, allocator);

    try stdout.writeAll("\x1b[?25l");
    try stdout.print("\x1b[1m{s}{s}\x1b[22m\n", .{ start_offset, start_text });
    try stdout.print("{s}{s}\x1b[1F", .{ settings_offset, settings_text });

    try stdout.flush();

    defer allocator.free(start_offset);
    defer allocator.free(settings_offset);

    var selected_option: u16 = 0;
    var selected_row = (try get_terminal_cursor_position(stdout, stdin))[0];

    // std.debug.print("{d}{d}", .{ selected_option, selected_row });

    while (true) {
        const b = try stdin.takeByte();
        if (b == 0x1b) {
            const sb = try stdin.takeByte();
            const tb = try stdin.takeByte();

            if (sb == '[' or sb == 'O') {
                switch (tb) {
                    'A' => {
                        if (selected_option == 1) {
                            try stdout.writeAll("\x1b[2K\r\x1b[22m");
                            try stdout.print("{s}{s}", .{ settings_offset, settings_text });

                            try stdout.print("\x1b[{d};0H", .{selected_row - 1});

                            try stdout.writeAll("\x1b[2K\r\x1b[1m");
                            try stdout.print("{s}{s}", .{ start_offset, start_text });

                            selected_option = 0;
                            selected_row = (try get_terminal_cursor_position(stdout, stdin))[0];
                        }

                        try stdout.flush();

                        // if (selected_option == 0) {
                        //     try stdout.print("{s}{s}\n", .{ start_offset, start_text });
                        // } else {
                        //     try stdout.print("{s}{s}\n", .{ settings_offset, settings_text });
                        // }
                    },
                    'B' => {
                        if (selected_option == 0) {
                            // Clear the current row and reset flashing formatting; Print previous line
                            try stdout.writeAll("\x1b[2K\r\x1b[22m");
                            try stdout.print("{s}{s}", .{ start_offset, start_text });

                            // Move cursor to selcted_row + 1
                            try stdout.print("\x1b[{d};0H", .{selected_row + 1});

                            // Clear line and print new line with flashing formatting
                            try stdout.writeAll("\x1b[2K\r\x1b[1m");
                            try stdout.print("{s}{s}", .{ settings_offset, settings_text });
                            selected_option = 1;
                            selected_row = (try get_terminal_cursor_position(stdout, stdin))[0];
                        }

                        try stdout.flush();
                    },
                    'C' => std.debug.print("Right", .{}),
                    'D' => std.debug.print("Left", .{}),
                    else => {},
                }
            }
        } else if (b == 0x0A) {
            if (selected_option == 0) return .Play;
        } else {
            // std.debug.print("{x}", .{b});
        }
    }
}

fn clamp_minus(a: u16, b: u16) u16 {
    if (b > a) return 0;
    return a - b;
}

fn get_terminal_cursor_position(stdout: *std.Io.Writer, stdin: *std.Io.Reader) ![2]u16 {
    try stdout.writeAll("\x1b[6n");
    try stdout.flush();

    while (true) {
        const b = try stdin.takeByte();
        if (b == 0x1b) {
            const next = try stdin.takeByte();
            if (next == '[') break;
        }
    }

    // 3. Read "<row>;<col>R" into a small stack buffer
    // var buf: [32]u8 = undefined;
    const response = try stdin.takeDelimiterExclusive('R');

    // 4. Split on ';' and parse integers
    var it = std.mem.splitScalar(u8, response, ';');
    const row_str = it.next() orelse return error.InvalidCursorResponse;
    const col_str = it.next() orelse return error.InvalidCursorResponse;

    return [_]u16{ try std.fmt.parseInt(u16, row_str, 10), try std.fmt.parseInt(u16, col_str, 10) };
}

fn get_terminal_size() ![2]u16 {
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
            const out = [_]u16{ buf.col, buf.row };
            return out;
        },
        else => return error.IoctlError,
    };
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

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
            try stdout.writeAll("\x1b[2J\x1b[0m");
            try game_loop(stdin, stdout, init.arena.allocator(), init.io);
        },
        .Options => {},
    }
}

const selected_game_size = 4;

fn game_loop(stdin: *std.Io.Reader, stdout: *std.Io.Writer, allocator: std.mem.Allocator, io: std.Io) !void {
    // .real is Unix time: nanoseconds since 1970-01-01T00:00:00Z.
    const now = std.Io.Clock.Timestamp.now(io, .real);
    const us = now.raw.toMicroseconds();

    const MyGame = zhh1.Game(selected_game_size);
    var game: MyGame = MyGame.init(@intCast(us));

    var success = false;

    while (!success) {
        try game.test_field();
        success = try game.solve(&game.fields);
    }

    var carved_field = try allocator.alloc(u8, game.game_size * game.game_size);

    try game.carve(&game.fields, carved_field[0..(selected_game_size * selected_game_size)]);
    @memcpy(&game.fields, carved_field);

    var cursor_position = [2]usize{ 2, 2 };

    var out_buf: [2048]u8 = undefined;
    var written = try render_game_state(&game.fields, game.game_size, allocator, &cursor_position, out_buf[0..]);

    try stdout.print("\x1b[{d};{d}H", .{ terminal_height / 2 - game.game_size, 0 });
    try stdout.writeAll(out_buf[0..written]);
    try stdout.flush();

    while (true) {
        const b = try stdin.takeByte();
        if (b == 0x1b) {
            const sb = try stdin.takeByte();
            const tb = try stdin.takeByte();

            if (sb == '[' or sb == 'O') {
                switch (tb) {
                    'A' => {
                        cursor_position[0] = neg_modulo(usize, cursor_position[0], 1, game.game_size - 1);
                    },
                    'B' => {
                        cursor_position[0] = (cursor_position[0] + 1) % game.game_size;
                    },
                    'C' => {
                        cursor_position[1] = (cursor_position[1] + 1) % game.game_size;
                    },
                    'D' => {
                        cursor_position[1] = neg_modulo(usize, cursor_position[1], 1, game.game_size - 1);
                    },
                    else => {},
                }
            }

            written = try render_game_state(&game.fields, game.game_size, allocator, &cursor_position, out_buf[0..]);
            try stdout.print("\x1b[{d};{d}H", .{ terminal_height / 2 - game.game_size, 0 });
            try stdout.writeAll(out_buf[0..written]);
            try stdout.flush();
        } else if (b == 0x20) {
            var val = game.fields[cursor_position[0] * game.game_size + cursor_position[1] .. cursor_position[0] * game.game_size + cursor_position[1] + 1];

            if (val[0] == 0) {
                val[0] = 1;
            } else if (val[0] == 1) {
                val[0] = 2;
            } else if (val[0] == 2) {
                val[0] = 0;
            }
            written = try render_game_state(&game.fields, game.game_size, allocator, &cursor_position, out_buf[0..]);
            try stdout.print("\x1b[{d};{d}H", .{ terminal_height / 2 - game.game_size, 0 });
            try stdout.writeAll(out_buf[0..written]);
            try stdout.flush();

            if (try game.is_solved(&game.fields)) {
                // try clear_terminal(stdout);

                const finished_ts = std.Io.Clock.Timestamp.now(io, .real);
                const finished_us = finished_ts.raw.toMicroseconds();

                try stdout.print("Ojoo! Finished in {d}s\n", .{@divFloor((finished_us - us), 1_000_000)});
                try stdout.flush();

                std.process.exit(0);
            }
        } else {
            // std.debug.print("{x}", .{b});
        }
    }

    std.process.exit(0);
}

fn clear_terminal(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1b[2J");
}

fn render_game_state(fields: []u8, game_size: usize, allocator: std.mem.Allocator, cursor_position: *[2]usize, out_buf: []u8) !usize {
    const field_size = game_size * 2 - 1;
    const field_offset = offset(terminal_width, field_size, allocator);

    var writer: std.Io.Writer = .fixed(out_buf);

    for (0..game_size) |row| {
        try writer.writeAll(field_offset);
        for (0..game_size) |col| {
            const char_to_print: u8 = switch (fields[row * game_size + col]) {
                0 => '_',
                1 => 'O',
                2 => 'X',
                else => '?',
            };
            if (row == cursor_position[0] and col == cursor_position[1]) {
                try writer.writeAll("\x1b[44m");
                try writer.print("{c}", .{char_to_print});
                try writer.writeAll("\x1b[49m ");
            } else {
                try writer.print("{c} ", .{char_to_print});
            }
        }
        try writer.writeAll("\n");
    }

    return writer.end;
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

fn clamp_minus(comptime T: type, a: T, b: T) T {
    if (b > a) return 0;
    return a - b;
}

fn neg_modulo(comptime T: type, a: T, b: T, m: T) T {
    if (b > a) return m;
    return (a - b) % m;
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

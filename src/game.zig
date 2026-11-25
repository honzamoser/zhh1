const std = @import("std");

// BLUE = 1
// RED = 2
fn Game(comptime size: usize) type {
    return struct {
        game_size: usize = size,
        fields: [size * size]u8,
        seed: u64,
        prng: std.Random.DefaultPrng,
        random: std.Random,

        pub fn init(seed: u64) Game(size) {
            // zig fmt: off

            var prng: std.Random.DefaultPrng = .init(seed);

            return Game(size){     
                .fields = undefined, 
                .seed = seed, 
                .prng = prng,
                .random = prng.random()
            };
            // zig fmt: on
        }

        pub fn generate_fields() !void {}

        pub fn test_field(self: *Game(size)) !void {
            // zig fmt: off
            self.*.fields = @splat(0);
            // zig fmt: on

            // const is_count_valid = self.verify_count_rule() catch |err| {
            //     return err;
            // };

            // std.debug.print("{s}\n", .{if (is_count_valid) "Count rule is valid" else "Count rule is invalid"});

            // const is_balance_valid = self.verify_balance_rule() catch |err| {
            //     return err;
            // };

            // std.debug.print("{s}\n", .{if (is_balance_valid) "Balance rule is valid" else "Balance rule is invalid"});

            // const is_no_duplicates_valid = self.verify_no_duplicates() catch |err| {
            //     return err;
            // };
            // std.debug.print("{s}\n", .{if (is_no_duplicates_valid) "No duplicates rule is valid" else "No duplicates rule is invalid"});
        }

        pub fn print_fields(self: *Game(size), field: *[size * size]u8) !void {
            for (field, 0..) |_field, index| {
                const value: u8 = if (_field == 1) 'O' else if (_field == 2) 'X' else '_';
                std.debug.print("{c} ", .{value});
                if ((index + 1) % self.game_size == 0) {
                    std.debug.print("\n", .{});
                }
            }
        }

        fn verify_count_rule(self: *Game(size), field: *[size * size]u8) !bool {

            // Check rows
            for (0..self.game_size) |row_index| {
                var in_series: u16 = 0;
                var last_value: u8 = 0;
                for (0..self.game_size) |col_index| {
                    const index = row_index * self.game_size + col_index;
                    const value = field[index];

                    if (value == last_value) {
                        in_series += 1;
                        if (in_series >= 3 and value != 0) {
                            return false;
                        }
                    } else {
                        in_series = 1;
                        last_value = value;
                    }
                }
            }

            // Check columns
            for (0..self.game_size) |col_index| {
                var in_series: u16 = 0;
                var last_value: u8 = 0;
                for (0..self.game_size) |row_index| {
                    const index = row_index * self.game_size + col_index;
                    const value = field[index];

                    if (value == last_value) {
                        in_series += 1;
                        if (in_series >= 3 and value != 0) {
                            return false;
                        }
                    } else {
                        in_series = 1;
                        last_value = value;
                    }
                }
            }

            return true;
        }

        fn verify_balance_rule(self: *Game(size), field: *[size * size]u8) !bool {
            // Check rows
            for (0..self.game_size) |row_index| {
                var total_1: u16 = 0;
                var total_2: u16 = 0;

                for (0..self.game_size) |col_index| {
                    const index = row_index * self.game_size + col_index;
                    const value = field[index];

                    if (value == 1) {
                        total_1 += 1;
                    } else if (value == 2) {
                        total_2 += 1;
                    }
                }

                if (total_1 > size / 2 or total_2 > size / 2) return false;
            }

            // Check columns
            for (0..self.game_size) |col_index| {
                var total_1: u16 = 0;
                var total_2: u16 = 0;
                for (0..self.game_size) |row_index| {
                    const index = row_index * self.game_size + col_index;
                    const value = field[index];

                    if (value == 1) {
                        total_1 += 1;
                    } else if (value == 2) {
                        total_2 += 1;
                    }
                }

                if (total_1 > size / 2 or total_2 > size / 2) return false;
            }

            return true;
        }

        fn verify_no_duplicates(self: *Game(size), field: *[size * size]u8) !bool {
            // Check rows
            for (0..self.game_size) |row_index| {
                const current_row = field[row_index * self.game_size .. (row_index + 1) * self.game_size];

                for (0..self.game_size - 1) |i| {
                    const check_row_id: usize = if (i >= row_index) i + 1 else i;
                    const check_row = field[check_row_id * self.game_size .. (check_row_id + 1) * self.game_size];
                    if (try recurse_compare_rows(current_row[0..], check_row[0..], null)) {
                        return false;
                    }
                }
            }

            // Check columns
            for (0..self.game_size) |col_index| {
                const current_row = self.pick_column(col_index, field);

                var format_buf: [size]u8 = undefined;
                try fmt_row(current_row[0..], &format_buf);

                for (0..self.game_size - 1) |i| {
                    const check_row_id: usize = if (i >= col_index) i + 1 else i;
                    const check_row = self.pick_column(check_row_id, field);

                    try fmt_row(check_row[0..], &format_buf);

                    if (try recurse_compare_rows(current_row[0..], check_row[0..], null)) {
                        return false;
                    }
                }
            }

            return true;
        }

        fn pick_column(self: *Game(size), col_index: usize, field: *[size * size]u8) [size]u8 {
            var column: [size]u8 = undefined;
            for (0..self.game_size) |row_index| {
                const index = row_index * self.game_size + col_index;
                column[row_index] = field[index];
            }

            // Return the value of the column - we don't slice the game data array, because we want to sample columns and slices
            // would require us to create a new array for each column, which is not efficient. Instead, we return the column as a fixed-size array.
            return column;
        }

        fn recurse_compare_rows(row1: []const u8, row2: []const u8, _index: ?usize) !bool {
            const index: usize = if (_index) |i| i else 0;

            // Arrays are different sizes; Can't compare.
            if (row1.len != row2.len) {
                return error.DifferentLengths;
            }

            // At the end of the array, it means they're equal.
            if (index >= row1.len) {
                return true;
            }

            // If even 1 value is different, we know the rows are not equal and we can return false.
            if (row1[index] != row2[index]) {
                return false;
            }

            // Row is incomplete -> Can't judge if they're the same
            if (row1[index] == 0 or row2[index] == 0) {
                return false;
            }

            // If the values are equal, we continue to the next value in the array.
            return try recurse_compare_rows(row1, row2, index + 1);
        }

        pub fn is_solved(self: *Game(size), field: *[size * size]u8) !bool {
            _ = self;
            for (field) |value| {
                if (value == 0) {
                    return false;
                }
            }
            return true;
        }

        fn count_slice(self: *Game(size), slice: []const u8) [3]usize {
            _ = self;
            var out: [3]usize = @splat(0);

            for (slice) |val| {
                if (val == 0) out[0] += 1;
                if (val == 1) out[1] += 1;
                if (val == 2) out[2] += 1;
            }

            return out;
        }

        fn generate_heuristics(self: *Game(size), fields: *[size * size]u8) [size * size]u8 {
            // For now, just adjacency bonus
            var heuristics: [size * size]u8 = undefined;
            // Add +1 to fields that have a occupied field next to them
            for (0..size * size) |i| {
                heuristics[i] = 0;

                if (fields[i] != 0) continue;

                if (fields[i] == 0) {
                    if (self.has_adjacent(i, fields)) heuristics[i] += 1;
                }
            }
            // Add +1 to the row or column for each occupied field -> XX__ = +2 for each
            // Row first
            for (0..self.game_size) |rid| {
                const row_slice = fields[rid * self.game_size .. self.game_size * (rid + 1)];
                const count = self.count_slice(row_slice);

                const point_addition: u8 = @intCast(count[1] + count[2]);

                for (0..self.game_size) |cid| {
                    if (row_slice[cid] == 0) {
                        heuristics[rid * self.game_size + cid] += point_addition;
                    }
                }
            }

            // Next columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid, fields);
                const count = self.count_slice(col_slice[0..self.game_size]);

                const point_addition: u8 = @intCast(count[1] + count[2]);
                if (point_addition == 0) continue;
                // std.debug.print("{d}", .{point_addition});

                for (0..self.game_size) |rid| {
                    if (col_slice[rid] == 0) {
                        heuristics[rid * self.game_size + cid] += point_addition;
                    }
                }
            }
            self.print_heuristic(heuristics);
            return heuristics;
        }

        fn print_heuristic(self: *Game(size), heuristic: [size * size]u8) void {
            // _ = self;
            for (heuristic, 0..) |field, i| {
                if (i > 0 and i % self.game_size == 0) {
                    std.debug.print("\n", .{});
                }

                std.debug.print("{d}", .{field});
            }
        }

        fn has_adjacent(self: *Game(size), index: usize, fields: *[size * size]u8) bool {
            const row = index / self.game_size;
            const col = index % self.game_size;

            if (row > 0) {
                if (fields[(row - 1) * self.game_size + col] != 0) {
                    return true;
                }
            }
            if (row < self.game_size - 1) {
                if (fields[(row + 1) * self.game_size + col] != 0) {
                    return true;
                }
            }
            if (col > 0) {
                if (fields[row * self.game_size + col - 1] != 0) {
                    return true;
                }
            }
            if (col < self.game_size - 1) {
                if (fields[row * self.game_size + col + 1] != 0) {
                    return true;
                }
            }

            return false;
        }

        fn solve_quota(self: *Game(size), field: *[size * size]u8) bool {
            for (0..self.game_size) |rid| {
                const row_slice = field[rid * self.game_size .. rid * self.game_size + self.game_size];
                const row_count = self.count_slice(row_slice);
                if (row_count[1] >= self.game_size / 2 and row_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the ROW with RED (2) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = rid * self.game_size + field_id;
                        const value = field[index];
                        if (value == 0) field[index] = 2;
                    }
                    return true;
                }

                if (row_count[2] >= self.game_size / 2 and row_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the ROW with BLUE (1) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = rid * self.game_size + field_id;
                        const value = field[index];
                        if (value == 0) field[index] = 1;
                    }
                    return true;
                }
            }

            // // Now, check columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid, field)[0..self.game_size];
                const col_count = self.count_slice(col_slice);

                if (col_count[1] >= self.game_size / 2 and col_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the COLUMN with RED (2) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = field_id * self.game_size + cid;
                        const value = field[index];
                        if (value == 0) field[index] = 2;
                    }
                    return true;
                }

                if (col_count[2] >= self.game_size / 2 and col_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the COLUMN with BLUE (1) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = field_id * self.game_size + cid;
                        const value = field[index];
                        if (value == 0) field[index] = 1;
                    }
                    return true;
                }
            }

            return false;
        }

        fn solve_consecutive(self: *Game(size), fields: *[size * size]u8) bool {
            for (0..self.game_size) |rid| {
                const row_slice = fields[rid * self.game_size .. rid * self.game_size + self.game_size];
                var last_value = row_slice[0];
                for (1..row_slice.len) |s_idx| {
                    if (row_slice[s_idx] == last_value and last_value != 0 and s_idx + 1 < row_slice.len and row_slice[s_idx + 1] == 0) {
                        // Automatically assuming we have 2 of the same values in a row
                        const opposite_value = self.opposite(last_value);
                        if (s_idx + 2 <= self.game_size) {
                            fields[rid * self.game_size + s_idx + 1] = opposite_value;
                            return true;
                        }
                    } else {
                        last_value = row_slice[s_idx];
                    }
                }

                // Go backwards too
                last_value = row_slice[row_slice.len - 1];
                var s_idx = row_slice.len - 2;
                while (s_idx > 0) {
                    if (row_slice[s_idx] == last_value and last_value != 0 and s_idx - 1 >= 0 and row_slice[s_idx - 1] == 0) {
                        fields[rid * self.game_size + (s_idx - 1)] = self.opposite(last_value);
                        return true;
                    } else {
                        last_value = row_slice[s_idx];
                    }
                    s_idx -= 1;
                }
            }

            // // Now, check columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid, fields)[0..self.game_size];
                var last_value = col_slice[0];

                for (1..col_slice.len) |s_idx| {
                    if (col_slice[s_idx] == last_value and last_value != 0 and s_idx + 1 < col_slice.len and col_slice[s_idx + 1] == 0) {
                        // Automatically assuming we have 2 of the same values in a row
                        const opposite_value = self.opposite(last_value);
                        if (s_idx + 1 <= self.game_size) {
                            fields[(s_idx + 1) * self.game_size + cid] = opposite_value;
                            return true;
                        }
                    } else {
                        last_value = col_slice[s_idx];
                    }
                }

                // Go backwards too
                last_value = col_slice[col_slice.len - 1];
                var s_idx = col_slice.len - 2;
                while (s_idx > 0) {
                    if (col_slice[s_idx] == last_value and last_value != 0 and s_idx - 1 >= 0 and col_slice[s_idx - 1] == 0) {
                        fields[(s_idx - 1) * self.game_size + cid] = self.opposite(col_slice[s_idx]);
                        return true;
                    } else {
                        last_value = col_slice[s_idx];
                    }
                    s_idx -= 1;
                }
            }

            return false;
        }

        fn solve_sandwich(self: *Game(size), fields: *[size * size]u8) bool {
            for (0..self.game_size) |rid| {
                var row_slice = fields[rid * self.game_size .. rid * self.game_size + self.game_size];

                for (0..self.game_size - 2) |s_idx| {
                    if (row_slice[s_idx] != 0 and row_slice[s_idx + 1] == 0 and row_slice[s_idx + 2] == row_slice[s_idx]) {
                        row_slice[s_idx + 1] = self.opposite(row_slice[s_idx]);
                        return true;
                    }
                }
            }

            // Now, check columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid, fields)[0..self.game_size];

                for (0..self.game_size - 2) |s_idx| {
                    // _ = s_idx;

                    if (col_slice[s_idx] != 0 and col_slice[s_idx + 1] == 0 and col_slice[s_idx + 2] == col_slice[s_idx]) {
                        fields[(s_idx + 1) * self.game_size + cid] = self.opposite(col_slice[s_idx]);
                        return true;
                    }
                }
            }

            return false;
        }

        fn map_hash(self: *Game(size), field: *[size * size]u8) u64 {
            _ = self;
            return std.hash.Wyhash.hash(0, field);
        }

        pub fn solve(self: *Game(size), fields: *[size * size]u8) !bool {
            var last_state = self.map_hash(fields);

            var ch: u8 = 1;
            var fail_row: usize = 0;

            var guess_state: [size * size]u8 = undefined;
            @memcpy(&guess_state, fields);

            while (!try self.is_solved(fields)) : (if (!try self.verify(fields)) {
                ch = self.opposite(ch);
                @memcpy(fields, &guess_state);
                fail_row += 1;
            }) {
                if (fail_row > 3) {
                    std.debug.print("Failed more than 3 times in a row. Unsolvable layout?\n", .{});
                    return false;
                }

                std.debug.print("---------------------- {d}\n", .{last_state});
                _ = try self.print_fields(fields);
                // RULE 1: Search for a finished quota; eg. where red = N/2 or blue = N/2
                if (self.solve_quota(fields)) continue;

                // RULE 2: Search for consecutive XX or OO
                if (self.solve_consecutive(fields)) {
                    std.debug.print("Solve_Consecutive \n", .{});
                    continue;
                }

                // RULE 2.5: Check for sandwiches (X_X, O_O)
                if (self.solve_sandwich(fields)) continue;

                var highest_val: usize = 0;
                var highest_indexes_count: usize = 0;
                var highest_indexes: [16]usize = undefined;
                for (self.generate_heuristics(fields), 0..std.math.pow(usize, size, 2)) |field, i| {
                    if (field > highest_val) {
                        highest_val = field;
                        highest_indexes[0] = i;
                        highest_indexes_count = 1;
                    }

                    if (field == highest_val and highest_indexes_count < 16) {
                        highest_indexes[highest_indexes_count] = i;
                        highest_indexes_count += 1;
                    }
                }

                // For now, always set it to 1(O)
                @memcpy(&guess_state, fields);
                const selected_field = self.random.intRangeAtMost(usize, 0, highest_indexes_count - 1);
                fields[highest_indexes[selected_field]] = ch;

                print_usize_slice(highest_indexes[0..]);
                std.debug.print("{d}", .{selected_field});

                if (last_state == self.map_hash(fields)) {
                    std.debug.print("No change deteceted, exiting... \n", .{});
                    break;
                }

                last_state = self.map_hash(fields);
            }

            std.debug.print("----------------------\n", .{});
            _ = try self.print_fields(fields);
            return true;
        }

        // fn count_col(self: *Game(size), cid: usize) struct { blue: usize, red: usize } {}

        fn opposite(self: *Game(size), val: u8) u8 {
            _ = self;
            return (val ^ 0b11);
        }

        pub fn verify(self: *Game(size), fields: *[size * size]u8) !bool {
            if (!try self.verify_count_rule(fields)) {
                std.debug.print("More than 2 tiles next to each other! Fail\n", .{});
                return false;
            }

            if (!try self.verify_balance_rule(fields)) {
                std.debug.print("More than N/2 tiles in a row or column! Fail\n", .{});
                return false;
            }

            if (!try self.verify_no_duplicates(fields)) {
                std.debug.print("More than 1 instance of a row or column! Fail\n", .{});
                return false;
            }

            return true;
        }

        pub fn carve(self: *Game(size), fields: *[std.math.pow(usize, size, 2)]u8) void {
            _ = self;

            // Basic algorithm: Select a random field, remove it, solve the puzzle and if it succeeds, remove another field and repeat.
            // If it fails, keep that field locked forever.

            for (0..self.game_size) |value| {
                const work_fields: [std.math.pow(usize, size, 2)]u8 = undefined;
                @memcpy(&test_field, fields);

                const random_field_to_remove = self.random.intRangeAtMost(usize, 0, self.game_size - value);
            }
        }
    };
}

fn print_usize_slice(slice: []const usize) void {
    std.debug.print("SLICE: [", .{});
    for (slice) |value| {
        std.debug.print("{d}, ", .{value});
    }
    std.debug.print("]", .{});
}

fn print_slice(slice: []const u8) void {
    std.debug.print("SLICE: [", .{});
    for (slice) |value| {
        std.debug.print("{d}, ", .{value});
    }
    std.debug.print("]", .{});
}

pub fn fmt_row(input: []const u8, out_buf: []u8) !void {
    for (input, 0..) |value, i| {
        const formatted_value: u8 = if (value == 1) 'O' else if (value == 2) 'X' else '_';
        out_buf[i] = formatted_value;
    }
}

test "Create a game and check its size" {
    const MyGame = Game(6);
    const game: MyGame = MyGame.init(12);
    try std.testing.expect(game.game_size == 4);
    try std.testing.expect(game.fields.len == std.math.pow(usize, 4, 2));
}

test "Create a game and populate its fields" {
    const MyGame = Game(6);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    try game.print_fields();

    // Add assertions to check the generated fields
}

test "Verify count rule" {
    const MyGame = Game(6);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    const is_count_valid = game.verify_count_rule() catch |err| {
        std.debug.print("Error verifying count rule: {s}\n", .{err});
        return;
    };
    try std.testing.expect(is_count_valid);
}

test "Verify balance rule" {
    const MyGame = Game(6);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    const is_balance_valid = game.verify_balance_rule() catch |err| {
        std.debug.print("Error verifying balance rule: {s}\n", .{err});
        return;
    };
    try std.testing.expect(is_balance_valid);
}

test "Verify no duplicates rule" {
    const MyGame = Game(6);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    const is_no_duplicates_valid = game.verify_no_duplicates() catch |err| {
        std.debug.print("Error verifying no duplicates rule: {}\n", .{err});
        return;
    };
    try std.testing.expect(is_no_duplicates_valid);
}

test "Solve" {
    const io = std.testing.io;

    // .real is Unix time: nanoseconds since 1970-01-01T00:00:00Z.
    const now = std.Io.Clock.Timestamp.now(io, .real);
    const secs = now.raw.toMicroseconds();

    const MyGame = Game(6);
    var game: MyGame = MyGame.init(@intCast(secs));
    try game.test_field();
    _ = try game.solve(&game.fields);
    const success = try game.verify(&game.fields);

    try std.testing.expect(success);
}

test "Carving" {
    const io = std.testing.io;

    // .real is Unix time: nanoseconds since 1970-01-01T00:00:00Z.
    const now = std.Io.Clock.Timestamp.now(io, .real);
    const secs = now.raw.toMicroseconds();

    const MyGame = Game(6);
    var game: MyGame = MyGame.init(@intCast(secs));
    try game.test_field();
    try game.solve();
    const success = try game.verify();

    try std.testing.expect(success);
}

test "Opposite" {
    var MyGame = Game(6).init(12);
    const test_1: u8 = 1;
    const test_2: u8 = 2;
    try std.testing.expect(MyGame.opposite(test_1) == test_2);
    try std.testing.expect(MyGame.opposite(test_2) == test_1);
}

test "Heuristic" {
    const MyGame = Game(6);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    try game.print_fields();

    _ = game.generate_heuristics();
}

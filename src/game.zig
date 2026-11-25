const std = @import("std");

// BLUE = 1
// RED = 2
fn Game(comptime size: usize) type {
    return struct {
        game_size: usize = size,
        fields: [size * size]u8,
        seed: u64,

        pub fn init(seed: u64) Game(size) {
            // zig fmt: off
            return Game(size){     
                .fields = undefined, 
                .seed = seed 
            };
            // zig fmt: on
        }

        pub fn generate_fields() !void {}

        pub fn test_field(self: *Game(size)) !void {
            // zig fmt: off
            self.*.fields = [_]u8 {
                0,0,2,0,0,0,
                0,0,2,0,0,0,
                0,0,0,0,0,0,
                1,0,0,0,0,1,
                0,0,0,0,2,0,
                2,0,0,0,0,0
            };
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

        pub fn print_fields(self: *Game(size)) !void {
            for (self.fields, 0..) |field, index| {
                const value: u8 = if (field == 1) 'O' else if (field == 2) 'X' else '_';
                std.debug.print("{c} ", .{value});
                if ((index + 1) % self.game_size == 0) {
                    std.debug.print("\n", .{});
                }
            }
        }

        fn verify_count_rule(self: *Game(size)) !bool {

            // Check rows
            for (0..self.game_size) |row_index| {
                var in_series: u16 = 0;
                var last_value: u8 = 0;
                for (0..self.game_size) |col_index| {
                    const index = row_index * self.game_size + col_index;
                    const value = self.fields[index];

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
                    const value = self.fields[index];

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

        fn verify_balance_rule(self: *Game(size)) !bool {
            // Check rows
            for (0..self.game_size) |row_index| {
                var total_1: u16 = 0;
                var total_2: u16 = 0;

                for (0..self.game_size) |col_index| {
                    const index = row_index * self.game_size + col_index;
                    const value = self.fields[index];

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
                    const value = self.fields[index];

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

        fn verify_no_duplicates(self: *Game(size)) !bool {
            // Check rows
            for (0..self.game_size) |row_index| {
                const current_row = self.fields[row_index * self.game_size .. (row_index + 1) * self.game_size];

                for (0..self.game_size - 1) |i| {
                    const check_row_id: usize = if (i >= row_index) i + 1 else i;
                    const check_row = self.fields[check_row_id * self.game_size .. (check_row_id + 1) * self.game_size];
                    if (try recurse_compare_rows(current_row[0..], check_row[0..], null)) {
                        return false;
                    }
                }
            }

            // Check columns
            for (0..self.game_size) |col_index| {
                const current_row = self.pick_column(col_index);

                var format_buf: [size]u8 = undefined;
                try fmt_row(current_row[0..], &format_buf);

                for (0..self.game_size - 1) |i| {
                    const check_row_id: usize = if (i >= col_index) i + 1 else i;
                    const check_row = self.pick_column(check_row_id);

                    try fmt_row(check_row[0..], &format_buf);

                    if (try recurse_compare_rows(current_row[0..], check_row[0..], null)) {
                        return false;
                    }
                }
            }

            return true;
        }

        fn pick_column(self: *Game(size), col_index: usize) [size]u8 {
            var column: [size]u8 = undefined;
            for (0..self.game_size) |row_index| {
                const index = row_index * self.game_size + col_index;
                column[row_index] = self.fields[index];
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

        pub fn is_solved(self: *Game(size)) !bool {
            for (self.fields) |field| {
                if (field == 0) {
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

        fn generate_heuristics(self: *Game(size)) [size * size]u8 {
            // For now, just adjacency bonus
            var heuristics: [size * size]u8 = undefined;
            for (0..size * size) |i| {
                heuristics[i] = 0;

                if (self.fields[i] == 0) {
                    if (self.has_adjacent(i)) heuristics[i] += 1;
                }
            }
            return heuristics;
        }

        fn has_adjacent(self: *Game(size), index: usize) bool {
            const row = index / self.game_size;
            const col = index % self.game_size;

            if (row > 0) {
                if (self.fields[(row - 1) * self.game_size + col] != 0) {
                    return true;
                }
            }
            if (row < self.game_size - 1) {
                if (self.fields[(row + 1) * self.game_size + col] != 0) {
                    return true;
                }
            }
            if (col > 0) {
                if (self.fields[row * self.game_size + col - 1] != 0) {
                    return true;
                }
            }
            if (col < self.game_size - 1) {
                if (self.fields[row * self.game_size + col + 1] != 0) {
                    return true;
                }
            }

            return false;
        }

        fn solve_quota(self: *Game(size)) bool {
            for (0..self.game_size) |rid| {
                const row_slice = self.fields[rid * self.game_size .. rid * self.game_size + self.game_size];
                const row_count = self.count_slice(row_slice);
                if (row_count[1] >= self.game_size / 2 and row_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the ROW with RED (2) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = rid * self.game_size + field_id;
                        const value = self.fields[index];
                        if (value == 0) self.fields[index] = 2;
                    }
                    return true;
                }

                if (row_count[2] >= self.game_size / 2 and row_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the ROW with BLUE (1) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = rid * self.game_size + field_id;
                        const value = self.fields[index];
                        if (value == 0) self.fields[index] = 1;
                    }
                    return true;
                }
            }

            // // Now, check columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid)[0..self.game_size];
                const col_count = self.count_slice(col_slice);

                if (col_count[1] >= self.game_size / 2 and col_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the COLUMN with RED (2) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = field_id * self.game_size + cid;
                        const value = self.fields[index];
                        if (value == 0) self.fields[index] = 2;
                    }
                    return true;
                }

                if (col_count[2] >= self.game_size / 2 and col_count[0] >= 1) {
                    // std.debug.print("Fill in the rest of the COLUMN with BLUE (1) \n", .{});
                    for (0..self.game_size) |field_id| {
                        const index = field_id * self.game_size + cid;
                        const value = self.fields[index];
                        if (value == 0) self.fields[index] = 1;
                    }
                    return true;
                }
            }

            return false;
        }

        fn solve_consecutive(self: *Game(size)) bool {
            for (0..self.game_size) |rid| {
                const row_slice = self.fields[rid * self.game_size .. rid * self.game_size + self.game_size];
                var last_value = row_slice[0];
                for (1..row_slice.len) |s_idx| {
                    if (row_slice[s_idx] == last_value and last_value != 0 and s_idx + 1 < row_slice.len and row_slice[s_idx + 1] == 0) {
                        // Automatically assuming we have 2 of the same values in a row
                        const opposite_value = self.opposite(last_value);
                        if (s_idx + 2 <= self.game_size) {
                            self.fields[rid * self.game_size + s_idx + 1] = opposite_value;
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
                        self.fields[rid * self.game_size + (s_idx - 1)] = self.opposite(last_value);
                        return true;
                    } else {
                        last_value = row_slice[s_idx];
                    }
                    s_idx -= 1;
                }
            }

            // // Now, check columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid)[0..self.game_size];
                var last_value = col_slice[0];

                for (1..col_slice.len) |s_idx| {
                    if (col_slice[s_idx] == last_value and last_value != 0 and s_idx + 1 < col_slice.len and col_slice[s_idx + 1] == 0) {
                        // Automatically assuming we have 2 of the same values in a row
                        const opposite_value = self.opposite(last_value);
                        if (s_idx + 1 <= self.game_size) {
                            self.fields[(s_idx + 1) * self.game_size + cid] = opposite_value;
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
                        self.fields[(s_idx - 1) * self.game_size + cid] = self.opposite(col_slice[s_idx]);
                        return true;
                    } else {
                        last_value = col_slice[s_idx];
                    }
                    s_idx -= 1;
                }
            }

            return false;
        }

        fn solve_sandwich(self: *Game(size)) bool {
            for (0..self.game_size) |rid| {
                var row_slice = self.fields[rid * self.game_size .. rid * self.game_size + self.game_size];

                for (0..self.game_size - 2) |s_idx| {
                    if (row_slice[s_idx] != 0 and row_slice[s_idx + 1] == 0 and row_slice[s_idx + 2] == row_slice[s_idx]) {
                        row_slice[s_idx + 1] = self.opposite(row_slice[s_idx]);
                        return true;
                    }
                }
            }

            // Now, check columns
            for (0..self.game_size) |cid| {
                const col_slice = self.pick_column(cid)[0..self.game_size];

                for (0..self.game_size - 2) |s_idx| {
                    // _ = s_idx;

                    if (col_slice[s_idx] != 0 and col_slice[s_idx + 1] == 0 and col_slice[s_idx + 2] == col_slice[s_idx]) {
                        self.fields[(s_idx + 1) * self.game_size + cid] = self.opposite(col_slice[s_idx]);
                        return true;
                    }
                }
            }

            return false;
        }

        fn map_state(self: *Game(size)) u64 {
            return std.hash.Wyhash.hash(0, &self.fields);
        }

        pub fn solve(self: *Game(size)) !void {
            _ = try self.print_fields();
            var last_state = self.map_state();

            var ch: u8 = 1;
            var fail_row: usize = 0;

            var guess_state: [size * size]u8 = undefined;
            @memcpy(&guess_state, &self.fields);

            while (!try self.is_solved()) : (if (!try self.verify()) {
                ch = self.opposite(ch);
                @memcpy(&self.fields, &guess_state);
                fail_row += 1;
            }) {
                if (fail_row > 3) {
                    std.debug.print("Failed more than 3 times in a row. Unsolvable layout?\n", .{});
                    break;
                }

                std.debug.print("---------------------- {d}\n", .{last_state});
                _ = try self.print_fields();
                // RULE 1: Search for a finished quota; eg. where red = N/2 or blue = N/2
                if (self.solve_quota()) continue;

                // RULE 2: Search for consecutive XX or OO
                if (self.solve_consecutive()) {
                    std.debug.print("Solve_Consecutive \n", .{});
                    continue;
                }

                // RULE 2.5: Check for sandwiches (X_X, O_O)
                if (self.solve_sandwich()) continue;

                var highest_val: usize = 0;
                var highest_index: usize = 0;
                for (self.generate_heuristics(), 0..std.math.pow(usize, size, 2)) |field, i| {
                    if (field > highest_val) {
                        highest_val = field;
                        highest_index = i;
                    }
                }

                // For now, always set it to 1(O)
                @memcpy(&guess_state, &self.fields);
                self.fields[highest_index] = ch;

                if (last_state == self.map_state()) {
                    std.debug.print("No change deteceted, exiting... \n", .{});
                    break;
                }

                last_state = self.map_state();
            }

            std.debug.print("----------------------\n", .{});
            _ = try self.print_fields();
        }

        // fn count_col(self: *Game(size), cid: usize) struct { blue: usize, red: usize } {}

        fn opposite(self: *Game(size), val: u8) u8 {
            _ = self;
            return (val ^ 0b11);
        }

        pub fn verify(self: *Game(size)) !bool {
            if (!try self.verify_count_rule()) {
                std.debug.print("More than 2 tiles next to each other! Fail\n", .{});
                return false;
            }

            if (!try self.verify_balance_rule()) {
                std.debug.print("More than N/2 tiles in a row or column! Fail\n", .{});
                return false;
            }

            if (!try self.verify_no_duplicates()) {
                std.debug.print("More than 1 instance of a row or column! Fail\n", .{});
                return false;
            }

            return true;
        }
    };
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
    const MyGame = Game(4);
    const game: MyGame = MyGame.init(12);
    try std.testing.expect(game.game_size == 4);
    try std.testing.expect(game.fields.len == std.math.pow(usize, 4, 2));
}

test "Create a game and populate its fields" {
    const MyGame = Game(4);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    try game.print_fields();

    // Add assertions to check the generated fields
}

test "Verify count rule" {
    const MyGame = Game(4);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    const is_count_valid = game.verify_count_rule() catch |err| {
        std.debug.print("Error verifying count rule: {s}\n", .{err});
        return;
    };
    try std.testing.expect(is_count_valid);
}

test "Verify balance rule" {
    const MyGame = Game(4);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    const is_balance_valid = game.verify_balance_rule() catch |err| {
        std.debug.print("Error verifying balance rule: {s}\n", .{err});
        return;
    };
    try std.testing.expect(is_balance_valid);
}

test "Verify no duplicates rule" {
    const MyGame = Game(4);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    const is_no_duplicates_valid = game.verify_no_duplicates() catch |err| {
        std.debug.print("Error verifying no duplicates rule: {}\n", .{err});
        return;
    };
    try std.testing.expect(is_no_duplicates_valid);
}

test "Solve" {
    const MyGame = Game(6);
    var game: MyGame = MyGame.init(12);
    try game.test_field();
    try game.solve();
    const success = try game.verify();

    try std.testing.expect(success);
}

test "Opposite" {
    const test_1: u8 = 1;
    const test_2: u8 = 2;
    try std.testing.expect(Game(4).opposite(test_1) == test_2);
    try std.testing.expect(Game(4).opposite(test_2) == test_1);
}

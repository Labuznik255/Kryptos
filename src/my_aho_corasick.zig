const std = @import("std");
const Allocator = std.mem.Allocator;
const List_T = @import("my_list.zig").List_T;

const Trie_Node_T = struct {
    next: [26]usize = .{0} ** 26,
    output: bool = false,
    const Self = @This();
    pub fn print(self: Self) void {
        for (self.next, 0..) |index, i| {
            if (index == 0) {
                //continue;
            }
            const letter: u8 = @as(u8, @intCast(i)) + 'a';
            std.debug.print("{}-{c} ,", .{ index, letter });
        }
        std.debug.print("{} \n", .{self.output});
    }
};

pub const word_status = enum {
    not,
    complete,
    partial,
};

pub const Trie_T = struct {
    list: *List_T(Trie_Node_T),
    allocator: Allocator,
    const Self = @This();
    pub fn init(init_size: usize, allocator: Allocator) !*Self {
        const trie_t: *Self = try allocator.create(Self);
        const list = try List_T(Trie_Node_T).init(init_size, allocator, Trie_Node_T{}, false);
        try list.append(Trie_Node_T{});
        trie_t.* = Trie_T{ .list = list, .allocator = allocator };
        return trie_t;
    }
    pub fn deinit(self: *Self) void {
        self.list.deinit();
        self.allocator.destroy(self);
    }
    pub fn add_word(self: *Self, string: []const u8) !void {
        var current_node = self.list.get(0) orelse unreachable;
        for (string) |ch| {
            if (ch < 'a' or ch > 'z') {
                //std.debug.print("character not in alphabet {c}\n", .{ch});
                continue;
            }
            const char_index: u8 = ch - 'a';

            //const char_index: u8 = self.alphabet.get(ch) orelse
            //    {
            //    std.debug.print("character not in alphabet {c}\n", .{ch});
            //    continue;
            //};
            var next_node_index: usize = current_node.next[char_index];
            if (next_node_index == 0) {
                next_node_index = self.list.end;
                current_node.next[char_index] = next_node_index;
                try self.list.append(Trie_Node_T{});
            }
            current_node = self.list.get(next_node_index) orelse unreachable;
        }
        current_node.output = true;
    }

    pub fn is_word(self: *Self, index: usize, string: []const u8) word_status {
        var current_node = self.list.get(index) orelse return word_status.not;
        for (string) |ch| {
            if (ch < 'a' or ch > 'z') {
                //std.debug.print("character not in alphabet {c}\n", .{ch});
                continue;
            }
            const char_index: u8 = ch - 'a';

            //const char_index: u8 = self.alphabet.get(ch) orelse
            //    {
            //    std.debug.print("character not in alphabet {c}\n", .{ch});
            //    continue;
            //};

            const new_node_index: usize = current_node.next[char_index];
            if (new_node_index == 0) {
                return word_status.not;
            }
            current_node = self.list.get(new_node_index) orelse unreachable;
        }
        if (current_node.output) {
            return word_status.complete;
        }
        return word_status.partial;
    }

    pub fn get_endings(self: *Self, index: usize, char: u8) void {
        _ = self;
        _ = index;
        _ = char;
    }

    pub fn load_from_file(self: *Self, file: std.fs.File) !void {
        var buf_reader = std.io.bufferedReader(file.reader());
        const reader = buf_reader.reader();

        var line = std.ArrayList(u8).init(self.allocator);
        defer line.deinit();

        const writer = line.writer();
        var line_no: usize = 0;
        while (reader.streamUntilDelimiter(writer, '\n', null)) {
            // Clear the line so we can reuse it.
            defer line.clearRetainingCapacity();
            line_no += 1;

            try self.add_word(line.items);
            //std.debug.print("{d}--{s}\n", .{ line_no, line.items });
        } else |err| switch (err) {
            error.EndOfStream => { // end of file
                if (line.items.len > 0) {
                    line_no += 1;
                    //std.debug.print("{d}--{s}\n", .{ line_no, line.items });
                }
            },
            else => return err, // Propagate error
        }

        std.debug.print("Total words loaded: {d}\n", .{line_no});
    }

    pub fn print(self: *Self) void {
        for (self.list.data, 0..) |node, i| {
            std.debug.print("{} | ", .{i});
            node.print();
        }
    }
};

test "test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    var trie = try Trie_T.init(10, allocator);
    defer trie.deinit();

    try trie.add_word("she");
    try trie.add_word("his");
    try trie.add_word("hers");
    try trie.add_word("hello");
    try trie.add_word("nejneobhospodarovavatelnejsimi");

    const is_word1 = trie.is_word(2, "ell");
    const is_word2 = trie.is_word(2, "ello");

    std.debug.print("Gucci {} {} {}\n", .{ @TypeOf(Trie_Node_T{}), is_word1, is_word2 });
}

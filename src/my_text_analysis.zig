const std = @import("std");
const AC_T = @import("my_aho_corasick.zig");
const word_status = AC_T.word_status;

const testing = std.testing;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

pub fn word_count(trie: *AC_T.Trie_T, text: []const u8) u32 {
    var count: u32 = 0;
    var sq_start: usize = 0;
    var sq_end: usize = 0;

    for (text, 0..) |_, i| {
        const sequence: []const u8 = text[sq_start .. sq_end + 1];

        switch (trie.is_word(0, sequence)) {
            word_status.complete => {
                count += 1;
                sq_start = i;
                sq_end = i + 1;
            },
            word_status.partial => {
                sq_end = i + 1;
            },
            word_status.not => {
                sq_start = i;
                sq_end = i + 1;
            },
        }
    }
    return count;
}

pub fn frequency_analysis(text: []const u8) [26]usize {
    var histogram: [26]usize = .{0} ** 26;
    for (text) |ch| {
        if (ch < 'a' or ch > 'z') {
            continue;
        }
        const char_index: u8 = ch - 'a';
        histogram[char_index] += 1;
    }
    return histogram;
}

pub fn frequency_analysis_relative(text: []const u8) [26]f32 {
    const histo: [26]usize = frequency_analysis(text);
    var relative_histo: [26]f32 = undefined;
    var sum: usize = 0;
    for (histo) |count| {
        sum += count;
    }
    for (histo, 0..) |count, i| {
        relative_histo[i] = @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(sum));
    }
    return relative_histo;
}

pub fn index_of_coincidence(text: []const u8) f32 {
    const histo: [26]usize = frequency_analysis(text);
    var ioc: f32 = 0;
    var sum: usize = 0;
    for (histo) |count| {
        sum += count;
    }
    for (histo) |count| {
        if (count == 0) {
            continue;
        }
        ioc += @as(f32, @floatFromInt(count * (count - 1))) / @as(f32, @floatFromInt(sum * (sum - 1)));
    }
    return ioc;
}

pub fn NgramMap(comptime T: type) type {
    return StringHashMap(ArrayList(T));
}

/// Finds all n-grams in the given text and returns their positions
/// Caller owns the returned map and must call deinit() on it
pub fn findNgrams(text: []const u8, n: usize, allocator: Allocator) !NgramMap(usize) {
    var map = NgramMap(usize).init(allocator);
    errdefer {
        var it = map.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        map.deinit();
    }

    // Return empty map for invalid n-gram sizes
    if (n > text.len or n == 0) {
        return map;
    }

    // Find all n-grams
    var i: usize = 0;
    while (i <= text.len - n) : (i += 1) {
        const ngram = text[i .. i + n];
        const gop = try map.getOrPut(ngram);

        if (!gop.found_existing) {
            // Initialize new list for this n-gram
            gop.value_ptr.* = ArrayList(usize).init(allocator);
        }

        try gop.value_ptr.append(i);
    }

    return map;
}

/// Properly cleans up the n-gram map and all its contained array lists
pub fn deinitNgrams(ngrams: *NgramMap(usize)) void {
    var it = ngrams.valueIterator();
    while (it.next()) |list| {
        list.deinit();
    }
    ngrams.deinit();
}

pub fn ngramDistances(ngrams: *NgramMap(usize), max_distance: usize, allocator: Allocator) ![]usize {
    var it = ngrams.valueIterator();
    var histo = try allocator.alloc(usize, max_distance);
    @memset(histo, 0);
    while (it.next()) |list| {
        var last_pos: usize = 0;
        for (list.items, 0..) |pos, i| {
            if (i == 0) {
                last_pos = pos;
                continue;
            }
            std.debug.print("pos {}, last_pos {}, pos - last_pos {}\n", .{ pos, last_pos, pos - last_pos });
            histo[pos - last_pos] += 1;
            last_pos = pos;
        }
    }
    return histo;
}

pub fn splitText(text: []const u8, number_of_pieces: usize, allocator: Allocator) ![][]const u8 {
    var subtexts = try allocator.alloc([]const u8, number_of_pieces);
    const subtext_len = text.len / number_of_pieces;
    for (0..number_of_pieces) |i| {
        subtexts[i] = try allocator.alloc(u8, subtext_len);
    }
    for (text, 0..) |ch, i| {
        subtexts[i % number_of_pieces][i / number_of_pieces] = ch;
    }
    return subtexts;
}

test "ngrams" {
    const allocator = std.testing.allocator;

    const text = "abcdabc";
    var ngrams = try findNgrams(text, 2, allocator);
    defer deinitNgrams(&ngrams);

    const distances = try ngramDistances(&ngrams, text.len, allocator);
    defer allocator.free(distances);
    for (distances) |distance| {
        std.debug.print("{}\n", .{distance});
    }
}

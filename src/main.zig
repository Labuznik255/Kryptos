const std = @import("std");
const clap = @import("clap");
const AC_T = @import("my_aho_corasick.zig");
const T_A = @import("my_text_analysis.zig");
const KRYPTOS = @import("my_kryptos.zig");

const Allocator = std.mem.Allocator;

const dict_file_name = "words_beta.txt";

fn brute_force() ![]const u8 {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-i, --instructions <FILE>    Json file containing instructions.
        \\-f, --file <FILE>     Text file containgin the text you want to analyze.
        \\
    );

    const parsers = comptime .{
        .FILE = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
        .assignment_separators = "=:",
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("--help\n", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if (res.args.instructions == null) {
        std.debug.print("instruction file needed!\n", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if (res.args.file == null) {
        std.debug.print("text file needed!\n", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    const instruction_file = res.args.instructions.?;

    const text_file = res.args.file.?;

    const max_size = std.math.maxInt(usize);

    const instruction_data = std.fs.cwd().readFileAlloc(allocator, instruction_file, max_size) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("File {s} not found! \n", .{instruction_file});
            return;
        }
        return err;
    };
    defer allocator.free(instruction_data);

    const text_data = std.fs.cwd().readFileAlloc(allocator, text_file, max_size) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("File {s} not found! \n", .{instruction_file});
            return;
        }
        return err;
    };
    defer allocator.free(text_data);

    var instructions = try std.json.parseFromSlice(Instructions_JSON, allocator, instruction_data, .{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true });
    defer instructions.deinit();

    const silent = instructions.value.config.silent;

    var trie = try AC_T.Trie_T.init(100, allocator);
    defer trie.deinit();

    const file = std.fs.cwd().openFile("words_beta.txt", .{}) catch |err| switch (err) {
        std.fs.File.OpenError.FileNotFound => {
            std.debug.print("File {s} not found!\n", .{dict_file_name});
            return;
        },
        else => return err,
    };
    defer file.close();

    try trie.load_from_file(file);
    std.debug.print("trie size: {}, end: {}\n", .{ trie.list.size, trie.list.end });

    _ = silent;

    var actions_list = try allocator.alloc(Action, instructions.value.steps.len);
    defer allocator.free(actions_list);
    for (instructions.value.steps, 0..) |step, i| {
        std.debug.print("{s}\n", .{step.tool});
        actions_list[i] = .{ .tool = std.meta.stringToEnum(Tools, step.tool) orelse Tools.unknown, .mode = std.meta.stringToEnum(Crypto_mode, step.mode) orelse Crypto_mode.unknown, .key1 = step.key1, .key2 = step.key2 };
    }

    const text_striped = try KRYPTOS.strip(text_data, allocator);
    defer allocator.free(text_striped);
    const word_count = try transform_text(text_striped, actions_list, instructions.value.config, trie, allocator);
    std.debug.print("Best solution contains {d} words. \n", .{word_count});
}

const Tools = enum { table, table_pass, table_double, shift, affine, subs_pass, viginere, unknown };
const Crypto_mode = enum { decrypt, encrypt, unknown };
const Instructions_JSON = struct {
    config: Config,
    steps: []struct { tool: []const u8, mode: []const u8, key1: []const u8, key2: []const u8 },
};

const Config = struct { perpetual_word_check: bool, silent: bool, word_treshold: u32 };
const Best_Match = struct {};

const Action = struct { tool: Tools, mode: ?Crypto_mode, key1: []const u8, key2: []const u8 };

fn transform_text(text: []const u8, actions_list: []Action, config: Config, trie: *AC_T.Trie_T, allocator: Allocator) !u32 {
    if (actions_list.len == 0) {
        const word_count = T_A.word_count(trie, text);
        if (!config.silent or word_count >= config.word_treshold) {
            std.debug.print("{s}\n", .{text});
            std.debug.print("word count: {d}\n", .{word_count});
        }
        return word_count;
    }
    const word_count_m: u32 = switch (actions_list[0].tool) {
        .table => blk: {
            const text_len = text.len;
            var word_count_m: u32 = 0;
            for (1..text_len) |i| {
                if (text_len % i == 0) {
                    const alter_text = switch (actions_list[0].mode.?) {
                        .decrypt => try KRYPTOS.full_table_decode(text, i, text_len / i, "", allocator),
                        .encrypt => try KRYPTOS.full_table_encode(text, i, text_len / i, "", allocator),
                        else => text,
                    };
                    defer allocator.free(alter_text);
                    const word_count = try transform_text(alter_text, actions_list[1..], config, trie, allocator);
                    if (!config.silent or word_count >= config.word_treshold) {
                        std.debug.print("table - size: {d}x{d}\n", .{ i, text_len / i });
                    }
                    word_count_m = if (word_count > word_count_m) word_count else word_count_m;
                }
            }
            break :blk word_count_m;
        },
        .table_pass => blk: {
            const text_len = text.len;
            var word_count_m: u32 = 0;
            for (1..text_len) |i| {
                if (text_len % i == 0 and i < 12) {
                    var key = try allocator.alloc(u8, i);
                    defer allocator.free(key);
                    for (0..i) |b| {
                        key[b] = @as(u8, @intCast(b)) + 'a';
                    }
                    const permutations = try getAllPermutations(allocator, key);
                    defer {
                        for (permutations) |perm| {
                            allocator.free(perm);
                        }
                        allocator.free(permutations);
                    }

                    for (permutations) |permutation| {
                        const alter_text = switch (actions_list[0].mode.?) {
                            .decrypt => try KRYPTOS.full_table_decode(text, i, text_len / i, permutation, allocator),
                            .encrypt => try KRYPTOS.full_table_encode(text, i, text_len / i, permutation, allocator),
                            else => text,
                        };
                        defer allocator.free(alter_text);
                        const word_count = try transform_text(alter_text, actions_list[1..], config, trie, allocator);
                        if (!config.silent or word_count >= config.word_treshold) {
                            std.debug.print("table - size: {d}x{d} - key: {s} \n", .{ i, text_len / i, permutation });
                        }
                        word_count_m = if (word_count > word_count_m) word_count else word_count_m;
                    }
                }
            }
            break :blk word_count_m;
        },
        .table_double => 0,
        .shift => blk: {
            var word_count_m: u32 = 0;
            for (0..26) |i| {
                const alter_text = switch (actions_list[0].mode.?) {
                    .decrypt => try KRYPTOS.shift(text, -@as(i8, @intCast(i)), allocator),
                    .encrypt => try KRYPTOS.shift(text, @as(i8, @intCast(i)), allocator),
                    else => text,
                };
                defer allocator.free(alter_text);
                const word_count = try transform_text(alter_text, actions_list[1..], config, trie, allocator);
                if (!config.silent or word_count >= config.word_treshold) {
                    std.debug.print("shift - {d}\n", .{i});
                }
                word_count_m = if (word_count > word_count_m) word_count else word_count_m;
            }
            break :blk word_count_m;
        },
        .affine => blk: {
            var word_count_m: u32 = 0;
            for (1..26) |a| {
                if (!areCoprime(@as(u32, @intCast(a)), 26)) {
                    continue;
                }
                for (0..26) |b| {
                    const alter_text = switch (actions_list[0].mode.?) {
                        .decrypt => try KRYPTOS.affine_decode(text, @as(u8, @intCast(a)), @as(u8, @intCast(b)), allocator),
                        .encrypt => try KRYPTOS.affine_encode(text, @as(u8, @intCast(a)), @as(u8, @intCast(b)), allocator),
                        else => text,
                    };
                    defer allocator.free(alter_text);
                    const word_count = try transform_text(alter_text, actions_list[1..], config, trie, allocator);
                    if (!config.silent or word_count >= config.word_treshold) {
                        std.debug.print("affine - a:{d}, b:{d}\n", .{ a, b });
                    }
                    word_count_m = if (word_count > word_count_m) word_count else word_count_m;
                }
            }
            break :blk word_count_m;
        },
        .subs_pass => 0,
        .viginere => blk: {
            var word_count_m: u32 = 0;
            var ngrams = try T_A.findNgrams(text, 2, allocator);
            defer T_A.deinitNgrams(&ngrams);
            const distances = try T_A.ngramDistances(&ngrams, text.len, allocator);
            defer allocator.free(distances);

            for (distances) |distance| {
                if (distance == 0) {
                    continue;
                }
            }

            word_count_m = 1;
            break :blk word_count_m;
        },
        else => blk: {
            std.debug.print("Unknown instruction\n", .{});
            break :blk 0;
        },
    };
    return word_count_m;
}

fn gcd(a: u32, b: u32) u32 {
    var x = a;
    var y = b;
    while (y != 0) {
        const temp = x % y;
        x = y;
        y = temp;
    }
    return x;
}

pub fn areCoprime(a: u32, b: u32) bool {
    return gcd(a, b) == 1;
}

pub fn getAllPermutations(allocator: std.mem.Allocator, input: []const u8) ![][]u8 {
    // Calculate total number of permutations (n!)
    var total: usize = 1;
    var i: usize = 1;
    while (i <= input.len) : (i += 1) {
        total *= i;
    }

    // Create array list to store all permutations
    var result = try std.ArrayList([]u8).initCapacity(allocator, total);
    errdefer {
        for (result.items) |item| {
            allocator.free(item);
        }
        result.deinit();
    }

    // Create array to track used characters
    var used = try allocator.alloc(bool, input.len);
    defer allocator.free(used);
    @memset(used, false);

    // Create buffer for current permutation
    var current = try allocator.alloc(u8, input.len);
    defer allocator.free(current);

    // Generate permutations recursively
    try generatePermutations(allocator, &result, input, current[0..], used[0..], 0);

    return result.toOwnedSlice();
}

fn generatePermutations(
    allocator: std.mem.Allocator,
    result: *std.ArrayList([]u8),
    input: []const u8,
    current: []u8,
    used: []bool,
    pos: usize,
) !void {
    // If we've filled all positions, add the permutation
    if (pos == input.len) {
        const perm = try allocator.dupe(u8, current);
        try result.append(perm);
        return;
    }

    // Try each character in the current position
    for (input, 0..) |char, i| {
        if (!used[i]) {
            used[i] = true;
            current[pos] = char;
            try generatePermutations(allocator, result, input, current, used, pos + 1);
            used[i] = false;
        }
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn shift(text: []const u8, key: i8, allocator: Allocator) ![]const u8 {
    const k: u8 = @as(u8, @intCast(@mod(key, @as(i8, 26))));
    var altered_text = try allocator.alloc(u8, text.len);
    std.mem.copyForwards(u8, altered_text, text);
    for (text, 0..) |ch, i| {
        var altered_char: u8 = ch + k;
        if (altered_char > 'z') {
            altered_char -= 26;
        }
        altered_text[i] = altered_char;
    }
    return altered_text;
}

pub fn affine_encode(text: []const u8, a: u8, b: u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, text.len);
    for (text, 0..) |ch, i| {
        const axch: u16 = @as(u16, a) * (ch - 'a');
        altered_text[i] = @as(u8, @intCast((axch + b) % 26)) + 'a';
    }
    return altered_text;
}

pub fn affine_decode(text: []const u8, a: u16, b: u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, text.len);
    var a_inverse: u16 = 0;
    for (0..26) |i| {
        a_inverse = @as(u16, @intCast(i));
        if ((a * a_inverse) % 26 == 1) {
            break;
        }
    }
    for (text, 0..) |ch, i| {
        altered_text[i] = @as(u8, @intCast(@mod(@as(i16, @intCast(a_inverse)) * (@as(i16, (ch - 'a')) - b), 26))) + 'a';
    }
    return altered_text;
}

fn rotate(text: []const u8, key: isize, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, text.len);
    for (text, 0..) |ch, i| {
        const index = @as(usize, @intCast(@mod(@as(isize, @intCast(i)) - key, @as(isize, @intCast(text.len)))));
        altered_text[index] = ch;
    }
    return altered_text;
}

pub fn strip(text: []const u8, allocator: Allocator) ![]const u8 {
    var size: usize = 0;
    for (text) |ch| {
        if (ch >= 'a' and ch <= 'z') {
            size += 1;
        }
    }

    var altered_text = try allocator.alloc(u8, size);

    var i: usize = 0;
    for (text) |ch| {
        if (ch >= 'a' and ch <= 'z') {
            altered_text[i] = ch;
            i += 1;
        }
    }
    return altered_text;
}

fn condense(text: []const u8) [26]u8 {
    var condensed: [26]u8 = .{0} ** 26;
    var a: u8 = 0;
    outer: for (text) |ch| {
        for (0..a) |i| {
            if (ch == condensed[i]) {
                continue :outer;
            }
        }
        condensed[a] = ch;
        a += 1;
    }
    return condensed;
}

fn fill_to_alphabet(text: []const u8) [26]u8 {
    var condensed = condense(text);
    var a: u8 = 0;
    for (condensed) |ch| {
        if (ch != 0) {
            a += 1;
        }
    }
    outer: for (0..26) |i| {
        for (0..26) |o| {
            if (condensed[o] == @as(u8, @intCast(i)) + 'a') {
                continue :outer;
            }
        }
        condensed[a] = @as(u8, @intCast(i)) + 'a';
        a += 1;
    }
    return condensed;
}

pub fn substitution(text: []const u8, key: []const u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, text.len);
    const filled_key = fill_to_alphabet(key);
    for (text, 0..) |ch, i| {
        if (ch < 'a' or ch - 'a' >= filled_key.len) {
            altered_text[i] = ch;
            continue;
        }
        altered_text[i] = filled_key[ch - 'a'];
    }
    return altered_text;
}

fn make_vigenere_squere(alphabet_key: []const u8, allocator: Allocator) ![]const u8 {
    const alphabet = fill_to_alphabet(alphabet_key);
    const viginere = try allocator.alloc(u8, 26);
    @memcpy(viginere, &alphabet);
    return viginere;
}

pub fn vigener_encode(text: []const u8, key: []const u8, vigeners_squere: []const u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, text.len);

    for (text, 0..) |ch, i| {
        var row: usize = undefined;
        if (key.len == 0) {
            row = i % 26;
        } else {
            row = key[i % key.len] - 'a';
        }
        const pos: usize = (row + (ch - 'a')) % 26;
        altered_text[i] = vigeners_squere[pos];
    }
    return altered_text;
}

pub fn vigener_decode(text: []const u8, key: []const u8, vigeners_squere: []const u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, text.len);

    for (text, 0..) |ch, i| {
        var row: usize = undefined;
        if (key.len == 0) {
            row = i % 26;
        } else {
            row = key[i % key.len] - 'a';
        }
        const pos: usize = (26 - row + (ch - 'a')) % 26;
        altered_text[i] = vigeners_squere[pos];
    }
    return altered_text;
}

pub fn full_table_encode(text: []const u8, m: usize, n: usize, key: []const u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, m * n);

    var i: usize = 0;
    for (0..m) |c| {
        for (0..n) |r| {
            var pos: usize = undefined;

            pos = r * m + c;
            if (key.len >= m) {
                pos = r * m + (key[c] - 'a');
            }
            if (text.len <= pos) {
                altered_text[i] = 'x';
            } else {
                altered_text[i] = text[pos];
            }
            i += 1;
        }
    }

    return altered_text;
}

pub fn full_table_decode(text: []const u8, m: usize, n: usize, key: []const u8, allocator: Allocator) ![]const u8 {
    var altered_text = try allocator.alloc(u8, m * n);

    var i: usize = 0;
    for (0..n) |r| {
        for (0..m) |c| {
            var pos: usize = undefined;
            pos = c * n + r;
            if (key.len >= m) {
                for (key, 0..) |k, o| {
                    if (k - 'a' == c) {
                        pos = o * n + r;
                    }
                }
            }
            if (text.len <= pos) {
                altered_text[i] = 'x';
            } else {
                altered_text[i] = text[pos];
            }
            i += 1;
        }
    }

    return altered_text;
}

test "shift" {
    var allocator = std.testing.allocator;

    const text: []const u8 = "abcdefghijklmnopqrstuvwxyz";
    const shift1 = try shift(text, 1, allocator);
    const shift16 = try shift(text, 16, allocator);
    const shift_5 = try shift(text, -5, allocator);
    defer allocator.free(shift1);
    defer allocator.free(shift16);
    defer allocator.free(shift_5);

    try std.testing.expectEqualStrings(shift1, "bcdefghijklmnopqrstuvwxyza");
    try std.testing.expectEqualStrings(shift16, "qrstuvwxyzabcdefghijklmnop");
    try std.testing.expectEqualStrings(shift_5, "vwxyzabcdefghijklmnopqrstu");
}

test "affine" {
    var allocator = std.testing.allocator;

    const text: []const u8 = "abcdefghijklmnopqrstuvwxyz";

    const affine9_15 = try affine_encode(text, 9, 15, allocator);
    const pt = try affine_decode(affine9_15, 9, 15, allocator);
    defer allocator.free(affine9_15);
    defer allocator.free(pt);

    try std.testing.expectEqualStrings(affine9_15, "pyhqzirajsbktcludmvenwfoxg");
    try std.testing.expectEqualStrings(pt, text);
}

test "fill" {
    const text: []const u8 = "heslohole";
    const filled = fill_to_alphabet(text);

    try std.testing.expectEqualStrings(&filled, "hesloabcdfgijkmnpqrtuvwxyz");
}

test "substitution" {
    var allocator = std.testing.allocator;

    const text: []const u8 = "abcdefghijklmnopqrstuvwxyz";

    const subs = try substitution(text, "hesloabcdfgijkmnpqrtuvwxyz", allocator);
    const subs1 = try substitution(text, "heslo", allocator);
    defer allocator.free(subs);
    defer allocator.free(subs1);

    try std.testing.expectEqualStrings(subs, "hesloabcdfgijkmnpqrtuvwxyz");
    try std.testing.expectEqualStrings(subs, subs1);
}

test "vigener" {
    var allocator = std.testing.allocator;

    const text1: []const u8 = "abcdefghijklmnopqrstuvwxyz";

    const vigeners_squere1 = try make_vigenere_squere("", allocator);
    defer allocator.free(vigeners_squere1);
    const vigener1 = try vigener_encode(text1, "", vigeners_squere1, allocator);
    defer allocator.free(vigener1);
    const pt1 = try vigener_decode(vigener1, "", vigeners_squere1, allocator);
    defer allocator.free(pt1);

    try std.testing.expectEqualStrings(vigener1, "acegikmoqsuwyacegikmoqsuwy");
    try std.testing.expectEqualStrings(pt1, text1);

    const text2: []const u8 = "attackatdawn";

    const vigeners_squere2 = try make_vigenere_squere("", allocator);
    defer allocator.free(vigeners_squere2);
    const vigener2 = try vigener_encode(text2, "defcon", vigeners_squere2, allocator);
    defer allocator.free(vigener2);
    const pt2 = try vigener_decode(vigener2, "defcon", vigeners_squere2, allocator);
    defer allocator.free(pt2);

    try std.testing.expectEqualStrings(vigener2, "dxycqxdxicka");
    try std.testing.expectEqualStrings(pt2, text2);
}

test "table" {
    var allocator = std.testing.allocator;

    const text: []const u8 = "abcdefghijkl";

    const table1 = try full_table_encode(text, 4, 3, "", allocator);
    defer allocator.free(table1);
    const pt1 = try full_table_decode(table1, 4, 3, "", allocator);
    defer allocator.free(pt1);

    const table2 = try full_table_encode(text, 4, 3, "dbca", allocator);
    defer allocator.free(table2);
    const pt2 = try full_table_decode(table2, 4, 3, "dbca", allocator);
    defer allocator.free(pt2);

    const text2: []const u8 = "hrestphoerncwhetnhteornetwoaaspalgalniedcerraasnhdihnemsiacthdiogwanniannidtstohmeebcaocnkgarnedsfsoirotnhamlorteiaocntwiaosnssotootthhienlgaatnedshtescuopurledmnetchoeuarrttghaeyrruisgthytssqdueecaikstihoantnjiochkntbuarkneerdhoafdfktehpettfvoarngdewtetnitnoguttooonitloxtxhxexbxaxkxex";
    const table3 = try full_table_encode(text2, 22, 13, "", allocator);
    defer allocator.free(table3);
    const pt3 = try full_table_decode(table3, 22, 13, "", allocator);
    defer allocator.free(pt3);

    try std.testing.expectEqualStrings(table1, "aeibfjcgkdhl");
    try std.testing.expectEqualStrings(pt1, text);

    try std.testing.expectEqualStrings(table2, "dhlbfjcgkaei");
    try std.testing.expectEqualStrings(pt2, text);

    try std.testing.expectEqualStrings(text2, pt3);
}

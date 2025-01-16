const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;
const Allocator = std.mem.Allocator;

const ListTError = error{
    ZeroSizeInitialization,
    ListOverflow,
    IncorrectEntryType,
};

pub fn List_T(comptime T: type) type {
    return comptime struct {
        size: usize,
        end: usize,
        data: []T,
        allocator: Allocator,
        default_value: T,
        shrinkable: bool,
        const Self = @This();

        pub fn init(init_size: usize, allocator: Allocator, default_value: T, shrinkable: bool) !*Self {
            if (init_size == 0) {
                std.debug.print("Cannot initialization size must be bigger than 0. \n", .{});
                return ListTError.ZeroSizeInitialization;
            }
            const list_t: *Self = try allocator.create(Self);
            const data = try allocator.alloc(T, init_size);
            var i: usize = 0;
            while (i < init_size) : (i += 1) {
                data[i] = default_value;
            }
            list_t.* = Self{ .size = init_size, .end = 0, .data = data, .allocator = allocator, .default_value = default_value, .shrinkable = shrinkable };

            return list_t;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
            self.allocator.destroy(self);
        }

        pub fn append(self: *Self, entry: T) !void {
            const ov = @addWithOverflow(self.end, 1);
            if (ov[1] != 0) {
                std.debug.print("array overflowed \n", .{});
                return ListTError.ListOverflow;
            }
            if (self.end >= self.size) {
                try self.inflate();
            }

            self.data[self.end] = entry;
            self.end = ov[0];
        }

        pub fn add(self: *Self, index: usize, entry: T) !void {
            while (index > self.size) {
                const ov = @addWithOverflow(self.end, 1);
                if (ov[1] != 0) {
                    std.debug.print("array overflowed \n", .{});
                    return ListTError.ListOverflow;
                }

                try self.inflate();
            }
            if (index > self.end) {
                self.end = index;
            }
            self.data[index] = entry;
        }

        pub fn get(self: *Self, index: usize) ?*T {
            if (index > self.end) {
                return null;
            }
            return &self.data[index];
        }

        pub fn pop(self: *Self) !?T {
            if (self.end == 0) {
                return null;
            }
            self.end -= 1;
            const entry: T = self.data[self.end];

            if (self.shrinkable and self.end <= @divTrunc(self.size, 3)) {
                try self.deflate();
            }

            return entry;
        }

        fn inflate(self: *Self) !void {
            const ov = @mulWithOverflow(self.size, 2);
            self.size = ov[0];
            self.data = try self.allocator.realloc(self.data, self.size);
            for (self.data[self.end..]) |*val| {
                val.* = self.default_value;
            }
        }

        fn deflate(self: *Self) !void {
            self.size = @divTrunc(self.size, 3);
            self.data = try self.allocator.realloc(self.data, self.size);
        }

        fn print(self: Self) void {
            var i: usize = 0;
            while (i < self.size) : (i += 1) {
                std.debug.print("{} ", .{self.data[i]});
            }
            std.debug.print("\n", .{});
        }
    };
}

test "init" {
    std.debug.print("testing init functionallity ... \n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const array = try List_T(u8).init(4, arena.allocator(), 0, true);
    try expect(eql(u8, array.data, &.{ 0, 0, 0, 0 }));
}

test "append" {
    std.debug.print("testing append functionallity ... \n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var array = try List_T(u8).init(2, arena.allocator(), 0, false);
    var entry: u8 = 1;
    try array.append(entry);
    entry = 3;
    try array.append(entry);
    entry = 9;
    try array.append(entry);
    array.print();
    try expect(eql(u8, array.data, &.{ 1, 3, 9, 0 }));
}

test "all" {
    std.debug.print("testing all functionallity ... \n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var array = try List_T(u8).init(10, arena.allocator(), 0, true);
    try array.append(1);
    try array.append(2);
    try array.append(3);
    try array.append(4);
    try array.append(5);
    try array.append(6);
    try array.append(7);
    try array.append(8);
    try array.append(9);
    try array.append(0);

    array.print();
    try expect(eql(u8, array.data, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }));

    try expect(try array.pop() == 0);
    try expect(try array.pop() == 9);
    try expect(try array.pop() == 8);
    try expect(try array.pop() == 7);
    try expect(try array.pop() == 6);
    try expect(try array.pop() == 5);
    try expect(try array.pop() == 4);

    array.print();
    try expect(eql(u8, array.data, &.{ 1, 2, 3 }));

    try expect(try array.pop() == 3);
    try expect(try array.pop() == 2);
    try expect(try array.pop() == 1);
    try expect(try array.pop() == null);

    array.print();
    try expect(eql(u8, array.data, &.{}));
}

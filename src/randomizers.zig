const std = @import("std");

pub fn OG1985(comptime T: type, pieces: []T) Randomizer(T) {
    return Randomizer(T){ .uniform = Uniform(T).init(pieces) };
}

pub fn TetrisWorlds(comptime T: type, pieces: []T, allocator: std.mem.Allocator) Randomizer(T) {
    return Randomizer(T){ .bag = Bag(T).init(pieces, allocator, 7) };
}

pub fn NES(comptime T: type, pieces: []T, allocator: std.mem.Allocator) Randomizer(T) {
    const subRandomizer = TerminalRandomizer(T){ .uniform = Uniform(T).init(pieces) };
    return Randomizer(T){ .avoidRecent = try AvoidRecent(T).init(pieces, allocator, subRandomizer, 1, 1) };
}

pub fn Randomizer(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        uniform: Uniform(T),
        bag: Bag(T),
        avoidRecent: AvoidRecent(T),

        pub fn select(self: *Self, r: anytype) T {
            switch (self.*) {
                inline else => |*case| return case.select(r),
            }
        }

        pub fn selected(self: *Self, x: T) void {
            switch (self.*) {
                inline else => |*case| return case.selected(x),
            }
        }

        pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
            switch (self.*) {
                .uniform => |case| {
                    return Randomizer(T){ .uniform = try case.clone(allocator) };
                },
                .bag => |case| {
                    return Randomizer(T){ .bag = try case.clone(allocator) };
                },
                .avoidRecent => |case| {
                    return Randomizer(T){ .avoidRecent = try case.clone(allocator) };
                },
            }
        }
    };
}

// A terminal randomizer cannot depend on other randomizers. This is necessary
// since we can't have Randomizer depend on itself which is what happens with
// meta-Randomizers like AvoidRecent.
fn TerminalRandomizer(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        uniform: Uniform(T),
        bag: Bag(T),

        pub fn select(self: *Self, r: anytype) T {
            switch (self.*) {
                inline else => |*case| return case.select(r),
            }
        }

        pub fn selected(self: *Self, x: T) void {
            switch (self.*) {
                inline else => |*case| return case.selected(x),
            }
        }

        pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
            switch (self.*) {
                .uniform => |case| {
                    return Randomizer(T){ .uniform = try case.clone(allocator) };
                },
                .bag => |case| {
                    return Randomizer(T){ .bag = try case.clone(allocator) };
                },
            }
        }
    };
}

fn Uniform(comptime T: type) type {
    return struct {
        const Self = @This();

        pieces: []const T,

        pub fn init(pieces: []const T) Self {
            return Self{ .pieces = pieces };
        }

        pub fn select(self: *Self, r: anytype) T {
            const i = r.nextInt(0, @intCast(self.pieces.len));

            return self.pieces[@intCast(i)];
        }

        pub fn selected(_: *Self, _: T) void {}

        pub fn clone(self: *const Self, _: std.mem.Allocator) !Self {
            return self.*;
        }
    };
}

fn AvoidRecent(comptime T: type) type {
    return struct {
        const Self: type = @This();

        pieces: []const T,
        history: std.ArrayList(T),
        retries: u8,
        memory: u8,
        subRandomizer: TerminalRandomizer(T),

        pub fn init(pieces: []T, allocator: std.mem.Allocator, subRandomizer: TerminalRandomizer(T), memory: u8, retries: u8) !Self {
            const historyInit = std.ArrayList(T).initCapacity(allocator, memory) catch unreachable;
            return Self{
                .pieces = pieces,
                .history = historyInit,
                .subRandomizer = subRandomizer,
                .memory = memory,
                .retries = retries,
            };
        }

        pub fn select(self: *Self, r: anytype) T {
            for (0..self.retries) |_| {
                var retry = false;
                const selection = self.subRandomizer.select(r);
                for (0..self.history.items.len) |i| {
                    if (selection.equal(&self.history.items[i])) {
                        retry = true;
                        continue;
                    }
                }
                if (!retry) {
                    return selection;
                }
            }
            return self.subRandomizer.select(r);
        }

        pub fn selected(self: *Self, x: T) void {
            if (self.history.items.len >= self.memory) {
                _ = self.history.pop();
            }
            self.history.insertAssumeCapacity(0, x);
        }

        pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
            return Self{ .retries = self.retries, .memory = self.memory, .pieces = self.pieces, .subRandomizer = self.subRandomizer, .history = try self.history.clone(allocator) };
        }
    };
}

fn Bag(comptime T: type) type {
    return struct {
        const Self = @This();

        initialPieces: []const T,
        contents: std.ArrayList(T),
        size: u32,

        pub fn init(initialPieces: []const T, allocator: std.mem.Allocator, size: u32) Self {
            const contents = std.ArrayList(T).initCapacity(allocator, size) catch unreachable;
            var bag = Self{ .initialPieces = initialPieces, .contents = contents, .size = size };
            bag.fill(initialPieces);
            return bag;
        }

        pub fn select(self: *Self, r: anytype) T {
            if (self.contents.items.len == 0) {
                self.fill(self.initialPieces);
            }

            const i = r.nextInt(0, @intCast(self.contents.items.len));

            return self.contents.orderedRemove(@intCast(i));
        }

        pub fn selected(_: *Self, _: T) void {}

        pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
            return Self{ .size = self.size, .initialPieces = self.initialPieces, .contents = try self.contents.clone(allocator) };
        }

        fn fill(self: *Self, pieces: []const T) void {
            std.debug.assert(self.contents.items.len == 0);
            for (0..self.size) |i| {
                self.contents.appendAssumeCapacity(pieces[i % pieces.len]);
            }
            std.debug.assert(self.contents.items.len > 0);
        }
    };
}

const TestRNG = struct {
    const Self = @This();

    pub fn nextInt(_: *TestRNG, _: i32, max: i32) i32 {
        return max - 1;
    }
};
const expectEqual = std.testing.expectEqual;

test "happy" {
    const allocator = std.testing.allocator;
    const IntBag = Bag(i32);
    var bag = IntBag.init(allocator, 3, &.{ 4, 5, 6 });
    defer bag.contents.deinit(allocator);

    var rng = TestRNG{};
    const x = bag.select(&rng);

    // TestRNG.nextInt returns max-1, so with 3 items it returns 2, which is index 2 -> value 6
    try expectEqual(@as(i32, 6), x);
}

const std = @import("std");

pub fn Bag(comptime T: type) type {
    return struct {
        const Self = @This();

        size: u32,
        initialPieces: []const T,
        contents: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator, size: u32, initialPieces: []const T) Self {
            const contents = std.ArrayList(T).initCapacity(allocator, size) catch unreachable;
            var bag = Self{ .size = size, .initialPieces = initialPieces, .contents = contents };
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

        pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
            const bag = Self{ .size = self.size, .initialPieces = self.initialPieces, .contents = try self.contents.clone(allocator) };
            return bag;
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

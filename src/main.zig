const GameSpec = struct { width: u8, height: u8 };

const std = @import("std");

pub fn main() void {
    const spec = GameSpec{
        .width = 10,
        .height = 20,
    };

    const allocator = std.heap.page_allocator; // TODO: ArenaAllocator
    const playfield_result = allocator.alloc(u8, spec.width * spec.height);
    if (playfield_result) |playfield| {
        defer allocator.free(playfield);
        @memset(playfield, 0);

        // Print playfield contents
        const playfield_slice = playfield[0 .. spec.width * spec.height];

        for (0..spec.height - 1) |y| {
            for (0..spec.width - 1) |x| {
                const idx = y * spec.width + x;
                const block = playfield_slice[idx];
                switch (block) {
                    0 => {
                        std.debug.print("_", .{});
                    },
                    else => {
                        std.debug.print("?", .{});
                    },
                }
            }
            std.debug.print("\n", .{});
        }
    } else |err| {
        std.debug.print("Allocation failed: {s}\n", .{@errorName(err)});
    }
}

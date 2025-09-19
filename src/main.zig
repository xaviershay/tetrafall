const GameSpec = struct { width: u8, height: u8 };
const Block = enum { none, garbage, z, s, j, l, t, o, i };
const Direction = enum { north, east, south, west };
const Coordinate = struct { x: i8, y: i8 };
const Tetromino = struct { pattern: [4]Coordinate, block: Block };

const Game = struct {
    spec: GameSpec,
    playfield: []Block,
    current: ?struct { position: Coordinate, orientation: Direction, tetromino: Tetromino },
};

const std = @import("std");

fn run() error{OutOfMemory}!void {
    //var rng = SimpleRNG.init(12345);
    const spec = GameSpec{
        .width = 10,
        .height = 20,
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var game = Game{
        .spec = spec,
        .playfield = try allocator.alloc(Block, spec.width * spec.height),
        .current = null,
        // .{
        //     .position = Coordinate{ .x = 0, .y = 0 },
        //     .orientation = Direction.north,
        //     .pattern = &[_]Coordinate{},
        // },
    };
    @memset(game.playfield, Block.none);

    const t = Tetromino{
        .block = Block.t,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = -1, .y = 1 },
            Coordinate{ .x = 0, .y = 1 },
            Coordinate{ .x = 1, .y = 1 },
        },
    };

    game.current = .{
        .tetromino = t,
        .orientation = Direction.north,
        .position = Coordinate{ .x = 5, .y = 10 },
    };

    const playfieldRender = try allocator.alloc(Block, spec.width * spec.height);
    @memcpy(playfieldRender, game.playfield);

    if (game.current != null) {
        const current = game.current.?;
        // TODO: rotation
        for (0..4) |i| {
            const offset = current.tetromino.pattern[i];
            const location = Coordinate{ .x = current.position.x + offset.x, .y = current.position.y + offset.y };

            if (location.x >= 0 and location.x < game.spec.width and location.y >= 0 and location.y < game.spec.height) {
                playfieldRender[@as(u8, @intCast(location.y)) * spec.width + @as(u8, @intCast(location.x))] = current.tetromino.block;
            }
        }
    }

    // Print playfield contents
    const playfield_slice = playfieldRender[0 .. spec.width * spec.height];

    for (0..spec.height - 1) |y| {
        for (0..spec.width - 1) |x| {
            const idx = y * spec.width + x;
            const block = playfield_slice[idx];
            switch (block) {
                Block.none => {
                    std.debug.print(" ", .{});
                },
                else => {
                    std.debug.print("█", .{});
                },
            }
        }
        std.debug.print("\n", .{});
    }
}
pub fn main() void {
    run() catch |err| {
        std.debug.print("Allocation failed: {s}\n", .{@errorName(err)});
    };
}

// Simple Linear Congruential Generator (LCG)
// Based on Numerical Recipes constants - widely tested and portable
const SimpleRNG = struct {
    seed: i32,

    // Initialize with seed (uses current timestamp if seed is 0)
    pub fn init(seed: i32) SimpleRNG {
        var actual_seed = seed;
        if (actual_seed == 0) {
            actual_seed = @intCast(std.time.timestamp() & 0x7FFFFFFF);
        }

        // Keep within 32-bit signed int range
        actual_seed = @mod(actual_seed, 2147483647);
        if (actual_seed <= 0) actual_seed += 2147483646;

        return SimpleRNG{ .seed = actual_seed };
    }

    // Generate next random number (0 to 2147483646)
    pub fn next(self: *SimpleRNG) i32 {
        self.seed = @mod(self.seed * 16807, 2147483647);
        return self.seed;
    }

    // Generate random float between 0 and 1 (exclusive)
    pub fn nextFloat(self: *SimpleRNG) f32 {
        return @as(f32, @floatFromInt(self.next() - 1)) / 2147483646.0;
    }

    // Generate random integer between min and max (inclusive)
    pub fn nextInt(self: *SimpleRNG, min: i32, max: i32) i32 {
        const range = max - min + 1;
        return @as(i32, @intFromFloat(self.nextFloat() * @as(f32, @floatFromInt(range)))) + min;
    }

    // Generate random boolean
    pub fn nextBool(self: *SimpleRNG) bool {
        return self.nextFloat() < 0.5;
    }

    // Reset seed
    pub fn setSeed(self: *SimpleRNG, seed: i32) void {
        self.seed = @mod(seed, 2147483647);
        if (self.seed <= 0) self.seed += 2147483646;
    }
};

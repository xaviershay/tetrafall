const std = @import("std");
const expect = std.testing.expect;

const GameSpec = struct { width: u8, height: u8, dimensions: Coordinate };
const Block = enum { none, garbage, z, s, j, l, t, o, i };
const Direction = enum { north, east, south, west };
const Coordinate = struct {
    x: i8,
    y: i8,
    fn add(self: *const Coordinate, other: Coordinate) Coordinate {
        return Coordinate{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    fn inBounds(self: *const Coordinate, topLeft: Coordinate, bottomRight: Coordinate) bool {
        return (self.x >= topLeft.x and self.y >= topLeft.y and self.x < bottomRight.x and self.y < bottomRight.y);
    }
};

test "coordinate.inBounds()" {
    const x = Coordinate{ .x = 0, .y = 10 };
    try expect(x.inBounds(.{ .x = 0, .y = 10 }, .{ .x = 1, .y = 11 }));
    try expect(!x.inBounds(.{ .x = 0, .y = 10 }, .{ .x = 0, .y = 11 }));
    try expect(!x.inBounds(.{ .x = 0, .y = 10 }, .{ .x = 1, .y = 10 }));
    try expect(!x.inBounds(.{ .x = 1, .y = 10 }, .{ .x = 1, .y = 11 }));
    try expect(!x.inBounds(.{ .x = 0, .y = 11 }, .{ .x = 1, .y = 11 }));
    try expect(!x.inBounds(.{ .x = 1, .y = 11 }, .{ .x = 1, .y = 11 }));
}

const Tetromino = struct { pattern: [4]Coordinate, block: Block };

const GameState = enum { running, halted };

const Game = struct {
    spec: GameSpec,
    state: GameState,
    playfield: []Block,
    current: ?struct { position: Coordinate, orientation: Direction, tetromino: Tetromino },

    fn at(self: *Game, coordinate: Coordinate) Block {
        if (coordinate.inBounds(Coordinate{ .x = 0, .y = 0 }, self.spec.dimensions)) {
            std.debug.print("{d}x{d} ", .{ coordinate.x, coordinate.y });
            const idx = @as(u8, @intCast(coordinate.y)) * self.spec.width + @as(u8, @intCast(coordinate.x));
            return self.playfield[idx];
        } else {
            return Block.none;
        }
    }

    fn setAt(self: *Game, coordinate: Coordinate, block: Block) void {
        if (coordinate.inBounds(Coordinate{ .x = 0, .y = 0 }, self.spec.dimensions)) {
            const idx = @as(u8, @intCast(coordinate.y)) * self.spec.width + @as(u8, @intCast(coordinate.x));
            self.playfield[idx] = block;
        }
    }
};

const t = Tetromino{
    .block = Block.t,
    .pattern = [4]Coordinate{
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = -1, .y = 0 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 1, .y = 0 },
    },
};

pub fn main() void {
    run() catch |err| {
        std.debug.print("Allocation failed: {s}\n", .{@errorName(err)});
    };
}

fn run() error{OutOfMemory}!void {
    //var rng = SimpleRNG.init(12345);
    const spec = GameSpec{ .width = 10, .height = 10, .dimensions = .{ .x = 10, .y = 10 } };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var game = Game{
        .spec = spec,
        .state = GameState.running,
        .playfield = try allocator.alloc(Block, spec.width * spec.height),
        .current = null,
        // .{
        //     .position = Coordinate{ .x = 0, .y = 0 },
        //     .orientation = Direction.north,
        //     .pattern = &[_]Coordinate{},
        // },
    };
    @memset(game.playfield, Block.none);

    while (game.state == GameState.running) {
        // Not in render so that we can dump debug stuff in update()
        const stdout = std.fs.File.stdout();
        _ = stdout.write("\x1b[2J\x1b[H") catch 0;

        update(&game);
        try render(game);
        std.Thread.sleep(1_000_000_00 / 3);
    }
}

fn update(game: *Game) void {
    if (game.current == null) {
        game.current = .{
            .tetromino = t,
            .orientation = Direction.north,
            .position = Coordinate{ .x = 5, .y = -1 },
        };
    }
    var p = &game.current.?.position;
    p.y += 1;

    const currentG = game.current.?;
    const currentT = currentG.tetromino;
    var blocked = false;

    for (currentT.pattern) |offset| {
        const location = p.add(offset);

        if (game.at(location) != Block.none or !location.inBounds(.{ .x = 0, .y = -1 }, game.spec.dimensions)) {
            p.y -= 1;
            blocked = true;
            // TODO: this should be < not <= and there's a flashing thing that happens at the end, so a bug somewhere.
            if (p.y <= 0) {
                game.state = GameState.halted;
                game.current = null;
            }
            break;
        }
    }

    if (blocked and game.state == GameState.running) {
        for (currentT.pattern) |offset| {
            const location = p.add(offset);

            game.setAt(location, currentT.block);
        }
        game.current = .{
            .tetromino = t,
            .orientation = Direction.north,
            .position = Coordinate{ .x = 5, .y = 0 },
        };
    }
}

fn render(game: Game) error{OutOfMemory}!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const spec = game.spec;
    const playfieldRender = try allocator.alloc(Block, spec.width * spec.height);
    @memcpy(playfieldRender, game.playfield);

    if (game.current != null) {
        const current = game.current.?;
        // TODO: rotation
        for (current.tetromino.pattern) |offset| {
            const location = current.position.add(offset);

            if (location.inBounds(.{ .x = 0, .y = 0 }, game.spec.dimensions)) {
                playfieldRender[@as(u8, @intCast(location.y)) * spec.width + @as(u8, @intCast(location.x))] = current.tetromino.block;
            }
        }
    }

    // Print playfield contents
    const playfield_slice = playfieldRender[0 .. spec.width * spec.height];

    std.debug.print("\n\n\n----------\n", .{});
    for (0..spec.height) |y| {
        for (0..spec.width) |x| {
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
    std.debug.print("==========\n", .{});
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

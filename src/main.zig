const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const rng = @import("simple_rng.zig");

const AI = struct { rng: rng.LCG, currentAction: Action, pendingActions: std.ArrayList(Action) };

const GameSpec = struct {
    dimensions: Coordinate,

    fn totalCells(self: *const GameSpec) u8 {
        return @as(u8, @intCast(self.dimensions.x)) * @as(u8, @intCast(self.dimensions.y));
    }
};
const Block = enum { none, oob, garbage, z, s, j, l, t, o, i };
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

fn maximum(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
pub fn rotate(orientation: Direction, p: [4]Coordinate) [4]Coordinate {
    var min: Coordinate = .{ .x = 0, .y = 0 };
    var max: Coordinate = .{ .x = 0, .y = 0 };
    for (p) |coord| {
        if (coord.x < min.x) {
            min.x = coord.x;
        }
        if (coord.y < min.y) {
            min.y = coord.y;
        }
        if (coord.x > max.x) {
            max.x = coord.x;
        }
        if (coord.y > max.y) {
            max.y = coord.y;
        }
    }

    const longestEdge = maximum(i8, max.x - min.x, max.y - min.y) + 1;

    return switch (longestEdge) {
        // A square is the only valid 4 coordinate pattern with edge length 2,
        // and is symmetric under rotation.
        2 => p,
        3 => rotate3x3(orientation, p),
        4 => rotate4x4(orientation, p),
        else => {
            std.debug.print("longestEdge: {any} {any}\n", .{ min, max });
            @panic("Malformed pattern");
        },
    };
}
pub fn rotate3x3(orientation: Direction, p: [4]Coordinate) [4]Coordinate {
    // TODO: This only works for size 3 tetrominos! Need to implement I.
    return switch (orientation) {
        Direction.north => p,
        Direction.east => [4]Coordinate{
            .{ .x = p[0].y * -1, .y = p[0].x },
            .{ .x = p[1].y * -1, .y = p[1].x },
            .{ .x = p[2].y * -1, .y = p[2].x },
            .{ .x = p[3].y * -1, .y = p[3].x },
        },
        Direction.west => [4]Coordinate{
            .{ .x = p[0].y, .y = p[0].x * -1 },
            .{ .x = p[1].y, .y = p[1].x * -1 },
            .{ .x = p[2].y, .y = p[2].x * -1 },
            .{ .x = p[3].y, .y = p[3].x * -1 },
        },
        Direction.south => [4]Coordinate{
            .{ .x = p[0].x * -1, .y = p[0].y * -1 },
            .{ .x = p[1].x * -1, .y = p[1].y * -1 },
            .{ .x = p[2].x * -1, .y = p[2].y * -1 },
            .{ .x = p[3].x * -1, .y = p[3].y * -1 },
        },
    };
}

pub fn rotate4x4(orientation: Direction, p: [4]Coordinate) [4]Coordinate {
    // Rotates a 4x4 grid around its center (0.5, 0.5)
    // Grid top-left corner is at (-1, -1), bottom-right at (2, 2)
    return switch (orientation) {
        Direction.north => p,
        Direction.east => [4]Coordinate{
            .{ .x = -p[0].y + 1, .y = p[0].x + 1 },
            .{ .x = -p[1].y + 1, .y = p[1].x + 1 },
            .{ .x = -p[2].y + 1, .y = p[2].x + 1 },
            .{ .x = -p[3].y + 1, .y = p[3].x + 1 },
        },
        Direction.west => [4]Coordinate{
            .{ .x = p[0].y - 1, .y = -p[0].x + 1 },
            .{ .x = p[1].y - 1, .y = -p[1].x + 1 },
            .{ .x = p[2].y - 1, .y = -p[2].x + 1 },
            .{ .x = p[3].y - 1, .y = -p[3].x + 1 },
        },
        Direction.south => [4]Coordinate{
            .{ .x = -p[0].x + 1, .y = -p[0].y + 1 },
            .{ .x = -p[1].x + 1, .y = -p[1].y + 1 },
            .{ .x = -p[2].x + 1, .y = -p[2].y + 1 },
            .{ .x = -p[3].x + 1, .y = -p[3].y + 1 },
        },
    };
}

test "rotate 2x2" {
    const initial = [4]Coordinate{
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 1, .y = 0 },
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = 1, .y = -1 },
    };
    const expected = [4]Coordinate{
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 1, .y = 0 },
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = 1, .y = -1 },
    };

    try expectEqual(expected, rotate(Direction.east, initial));
}

test "rotate clockwise 3x3" {
    const initial = [4]Coordinate{
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = -1, .y = 0 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 1, .y = 0 },
    };
    const expected = [4]Coordinate{
        Coordinate{ .x = 1, .y = 0 },
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 0, .y = 1 },
    };

    try expectEqual(expected, rotate(Direction.east, initial));
}

test "rotate counter-clockwise 3x3" {
    const initial = [4]Coordinate{
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = -1, .y = 0 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 1, .y = 0 },
    };
    const expected = [4]Coordinate{
        Coordinate{ .x = -1, .y = 0 },
        Coordinate{ .x = 0, .y = 1 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 0, .y = -1 },
    };

    try expectEqual(expected, rotate(Direction.west, initial));
}

test "rotate4x4 clockwise I-piece" {
    // I-piece in horizontal position in 4x4 grid
    const initial = [4]Coordinate{
        Coordinate{ .x = -1, .y = 1 },
        Coordinate{ .x = 0, .y = 1 },
        Coordinate{ .x = 1, .y = 1 },
        Coordinate{ .x = 2, .y = 1 },
    };
    // After 90° clockwise rotation should be vertical
    const expected = [4]Coordinate{
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 0, .y = 1 },
        Coordinate{ .x = 0, .y = 2 },
        Coordinate{ .x = 0, .y = 3 },
    };

    try expectEqual(expected, rotate(Direction.east, initial));
}

test "rotate4x4 counter-clockwise I-piece" {
    // I-piece in horizontal position in 4x4 grid
    const initial = [4]Coordinate{
        Coordinate{ .x = -1, .y = 1 },
        Coordinate{ .x = 0, .y = 1 },
        Coordinate{ .x = 1, .y = 1 },
        Coordinate{ .x = 2, .y = 1 },
    };
    // After 90° counter-clockwise rotation should be vertical
    const expected = [4]Coordinate{
        Coordinate{ .x = 0, .y = 2 },
        Coordinate{ .x = 0, .y = 1 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 0, .y = -1 },
    };

    try expectEqual(expected, rotate(Direction.west, initial));
}

test "rotate4x4 180 degrees I-piece" {
    // I-piece in horizontal position in 4x4 grid
    const initial = [4]Coordinate{
        Coordinate{ .x = -1, .y = 1 },
        Coordinate{ .x = 0, .y = 1 },
        Coordinate{ .x = 1, .y = 1 },
        Coordinate{ .x = 2, .y = 1 },
    };
    // After 180° rotation should be horizontal but flipped
    const expected = [4]Coordinate{
        Coordinate{ .x = 2, .y = 0 },
        Coordinate{ .x = 1, .y = 0 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = -1, .y = 0 },
    };

    try expectEqual(expected, rotate(Direction.south, initial));
}
const GameState = enum { running, halted };
const DroppingPiece = struct {
    position: Coordinate,
    orientation: Direction,
    tetromino: Tetromino,

    fn pattern(self: *const DroppingPiece) [4]Coordinate {
        return rotate(self.orientation, self.tetromino.pattern);
    }
};

const Action = enum { left, right, rotate_cw, rotate_ccw, soft_drop, hard_drop };

const Game = struct {
    spec: GameSpec,
    state: GameState,
    tetrominos: []Tetromino,
    playfield: []Block,
    rng: rng.LCG,
    current: ?DroppingPiece,

    fn indexFor(self: *const Game, coordinate: Coordinate) u8 {
        return @as(u8, @intCast(coordinate.y)) * @as(u8, @intCast(self.spec.dimensions.x)) + @as(u8, @intCast(coordinate.x));
    }

    fn at(self: *const Game, coordinate: Coordinate) Block {
        if (coordinate.inBounds(Coordinate{ .x = 0, .y = 0 }, self.spec.dimensions)) {
            return self.playfield[self.indexFor(coordinate)];
        } else {
            return Block.oob;
        }
    }

    fn setAt(self: *Game, coordinate: Coordinate, block: Block) void {
        if (coordinate.inBounds(Coordinate{ .x = 0, .y = 0 }, self.spec.dimensions)) {
            self.playfield[self.indexFor(coordinate)] = block;
        }
    }

    fn nextPiece(self: *Game) Tetromino {
        return self.tetrominos[self.rng.nextUint() % self.tetrominos.len];
    }

    fn apply(self: *Game, action: Action) void {
        switch (action) {
            Action.left => {
                if (self.current != null) {
                    var piece = self.current.?;
                    piece.position.x -= 1;

                    if (self.isValidPiece(piece)) {
                        self.current.?.position.x -= 1;
                    }
                }
            },
            Action.right => {
                if (self.current != null) {
                    var piece = self.current.?;
                    piece.position.x += 1;

                    if (self.isValidPiece(piece)) {
                        self.current.?.position.x += 1;
                    }
                }
            },
            else => {},
        }
    }

    fn isValidPiece(self: *const Game, piece: DroppingPiece) bool {
        const pattern = rotate(piece.orientation, piece.tetromino.pattern);

        var blocked = false;

        for (pattern) |offset| {
            const location = piece.position.add(offset);

            if (self.at(location) != Block.none) {
                blocked = true;
                break;
            }
        }
        return !blocked;
    }
};

pub fn main() void {
    run() catch |err| {
        std.debug.print("Allocation failed: {s}\n", .{@errorName(err)});
    };
}

fn run() error{OutOfMemory}!void {
    const spec = GameSpec{ .dimensions = .{ .x = 10, .y = 22 } };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var ai = AI{ .currentAction = Action.left, .rng = rng.LCG.init(0), .pendingActions = std.ArrayList(Action).empty };
    // TODO: I think one of these is wrong
    const tetrominos: []Tetromino = try allocator.alloc(Tetromino, 7);
    tetrominos[0] = Tetromino{
        .block = Block.t,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 0, .y = -1 },
            Coordinate{ .x = -1, .y = 0 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 1, .y = 0 },
        },
    };
    tetrominos[1] = Tetromino{
        .block = Block.j,
        .pattern = [4]Coordinate{
            Coordinate{ .x = -1, .y = -1 },
            Coordinate{ .x = -1, .y = 0 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 1, .y = 0 },
        },
    };
    tetrominos[2] = Tetromino{
        .block = Block.l,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 1, .y = -1 },
            Coordinate{ .x = -1, .y = 0 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 1, .y = 0 },
        },
    };
    tetrominos[3] = Tetromino{
        .block = Block.i,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 2, .y = 0 },
            Coordinate{ .x = 1, .y = 0 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = -1, .y = 0 },
        },
    };
    tetrominos[4] = Tetromino{
        .block = Block.o,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 1, .y = 0 },
            Coordinate{ .x = 0, .y = -1 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 0, .y = 1 },
        },
    };

    tetrominos[5] = Tetromino{
        .block = Block.s,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 1, .y = 0 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 0, .y = -1 },
            Coordinate{ .x = 1, .y = -1 },
        },
    };

    tetrominos[6] = Tetromino{
        .block = Block.z,
        .pattern = [4]Coordinate{
            Coordinate{ .x = 1, .y = -1 },
            Coordinate{ .x = 0, .y = -1 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 1, .y = 0 },
        },
    };
    var game = Game{
        .spec = spec,
        .state = GameState.running,
        .tetrominos = tetrominos,
        .rng = rng.LCG.init(123),
        .playfield = try allocator.alloc(Block, spec.totalCells()),
        .current = null,
    };
    @memset(game.playfield, Block.none);

    while (game.state == GameState.running) {
        // Not in render so that we can dump debug stuff in update()
        const stdout = std.fs.File.stdout();
        _ = stdout.write("\x1b[2J\x1b[H") catch 0;

        if (game.current != null and game.current.?.position.y <= 1) {
            if (ai.rng.nextBool()) {
                try ai.pendingActions.append(allocator, Action.left);
                try ai.pendingActions.append(allocator, Action.left);
            } else {
                try ai.pendingActions.append(allocator, Action.right);
                try ai.pendingActions.append(allocator, Action.right);
            }
        }
        if (ai.pendingActions.pop()) |action| {
            game.apply(action);
        }
        update(&game);
        try render(game);
        std.Thread.sleep(1_000_000_00 / 3);
    }
}

fn update(game: *Game) void {
    if (game.current == null) {
        game.current = .{
            .tetromino = game.nextPiece(),
            .orientation = Direction.north,
            .position = Coordinate{ .x = 5, .y = 1 },
        };
    }
    var p = &game.current.?.position;
    p.y += 1;

    const currentPiece = game.current.?;
    const currentT = currentPiece.tetromino;
    const pattern = currentPiece.pattern();
    var blocked = false;

    for (pattern) |offset| {
        const location = p.add(offset);

        if (game.at(location) != Block.none) {
            p.y -= 1;
            blocked = true;
            if (p.y <= 1) {
                game.state = GameState.halted;
            }
            break;
        }
    }

    if (blocked and game.state == GameState.running) {
        for (pattern) |offset| {
            const location = p.add(offset);

            game.setAt(location, currentT.block);
        }
        game.current = .{
            .tetromino = game.nextPiece(),
            .orientation = Direction.north,
            .position = Coordinate{ .x = 5, .y = 1 },
        };
    }
}

fn render(game: Game) error{OutOfMemory}!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const spec = game.spec;
    const playfieldRender = try allocator.alloc(Block, spec.totalCells());
    @memcpy(playfieldRender, game.playfield);

    if (game.current != null) {
        const current = game.current.?;
        // TODO: rotation
        for (current.pattern()) |offset| {
            const location = current.position.add(offset);

            if (location.inBounds(.{ .x = 0, .y = 0 }, game.spec.dimensions)) {
                playfieldRender[game.indexFor(location)] = current.tetromino.block;
            }
        }
    }

    // Print playfield contents
    const playfield_slice = playfieldRender[0..spec.totalCells()];

    std.debug.print("\n\n\n----------\n", .{});
    for (0..@as(u8, @intCast(spec.dimensions.y))) |y| {
        for (0..@as(u8, @intCast(spec.dimensions.x))) |x| {
            const idx = game.indexFor(.{ .x = @intCast(x), .y = @intCast(y) });
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

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const rng = @import("simple_rng.zig");
const randomizers = @import("randomizers.zig");

// Force inclusion of all module tests
test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(rng);
    std.testing.refAllDecls(randomizers);
}

const AI = struct { rng: rng.LCG, currentAction: Action, pendingActions: std.ArrayList(Action) };

const GameSpec = struct {
    dimensions: Coordinate,

    fn totalCells(self: *const GameSpec) u8 {
        return @as(u8, @intCast(self.dimensions.x)) * @as(u8, @intCast(self.dimensions.y));
    }
};
const Block = enum { none, oob, garbage, z, s, j, l, t, o, i };
const Direction = enum {
    north,
    east,
    south,
    west,

    fn rotate_cw(dir: Direction) Direction {
        return switch (dir) {
            Direction.north => Direction.east,
            Direction.east => Direction.south,
            Direction.south => Direction.west,
            Direction.west => Direction.north,
        };
    }

    fn rotate_ccw(dir: Direction) Direction {
        return switch (dir) {
            Direction.north => Direction.west,
            Direction.east => Direction.north,
            Direction.south => Direction.east,
            Direction.west => Direction.south,
        };
    }
};
const Coordinate = struct {
    x: i8,
    y: i8,
    fn fromU(x: usize, y: usize) Coordinate {
        return Coordinate{ .x = @intCast(x), .y = @intCast(y) };
    }

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

fn GameG(comptime T: type) type {
    return struct {
        const Self = @This();

        spec: GameSpec,
        state: GameState,
        tetrominos: []Tetromino,
        playfield: []Block,
        rng: rng.LCG,
        current: ?DroppingPiece,
        randomizer: T,

        fn init(allocator: std.mem.Allocator, tetrominos: []Tetromino, randomizer: T) !Self {
            const spec = GameSpec{ .dimensions = .{ .x = 10, .y = 22 } };
            const game = Self{
                .spec = spec,
                .state = GameState.running,
                .tetrominos = tetrominos,
                .rng = rng.LCG.init(123),
                .playfield = try allocator.alloc(Block, spec.totalCells()),
                .current = null,
                .randomizer = randomizer,
            };
            return game;
        }

        fn width(self: *const Self) usize {
            return @intCast(self.spec.dimensions.x);
        }

        fn height(self: *const Self) usize {
            return @intCast(self.spec.dimensions.y);
        }

        fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
            var copy = Self{ .spec = self.spec, .state = self.state, .tetrominos = self.tetrominos, .rng = self.rng, .playfield = self.playfield, .current = self.current, .randomizer = try self.randomizer.clone(allocator) };
            copy.playfield = try allocator.dupe(Block, self.playfield);
            // tetrominos NOT copied because expected to be constant.
            return copy;
        }

        fn indexFor(self: *const Self, coordinate: Coordinate) u8 {
            return @as(u8, @intCast(coordinate.y)) * @as(u8, @intCast(self.spec.dimensions.x)) + @as(u8, @intCast(coordinate.x));
        }

        fn at(self: *const Self, coordinate: Coordinate) Block {
            if (coordinate.inBounds(Coordinate{ .x = 0, .y = 0 }, self.spec.dimensions)) {
                return self.playfield[self.indexFor(coordinate)];
            } else {
                return Block.oob;
            }
        }

        fn setAt(self: *Self, coordinate: Coordinate, block: Block) void {
            if (coordinate.inBounds(Coordinate{ .x = 0, .y = 0 }, self.spec.dimensions)) {
                self.playfield[self.indexFor(coordinate)] = block;
            }
        }

        fn nextPiece(self: *Self) Tetromino {
            return self.tetrominos[self.rng.nextUint() % self.tetrominos.len];
        }

        fn lockCurrentPiece(self: *Self) void {
            //std.debug.print("===> LOCKING PIECE <=== ", .{});
            // Copy current piece to playfield
            const pattern = rotate(self.current.?.orientation, self.current.?.tetromino.pattern);
            for (pattern) |offset| {
                const location = self.current.?.position.add(offset);

                self.setAt(location, self.current.?.tetromino.block);
            }

            // Score any lines.
            for (0..@intCast(self.spec.dimensions.y)) |y| {
                const rowIndex = @as(u8, @intCast(self.spec.dimensions.y)) - y - 1;
                var line = true;
                var empty = true;
                for (0..@intCast(self.spec.dimensions.x)) |x| {
                    //std.debug.print("{any} ", .{self.at(Coordinate.fromU(x, rowIndex))});
                    if (self.at(Coordinate.fromU(x, rowIndex)) == Block.none) {
                        line = false;
                    } else {
                        empty = false;
                    }
                    if (!line and !empty) break;
                }
                //std.debug.print("\n", .{});
                if ((line or empty) and rowIndex > 0) {
                    for (0..@intCast(self.spec.dimensions.x)) |x| {
                        const from = Coordinate.fromU(x, rowIndex - 1);
                        const to = Coordinate.fromU(x, rowIndex);
                        self.setAt(to, self.at(from));
                        self.setAt(from, Block.none);
                    }
                }
            }

            self.current = .{
                .tetromino = self.nextPiece(),
                .orientation = Direction.north,
                .position = Coordinate{ .x = 5, .y = 1 },
            };
        }

        fn apply(self: *Self, action: Action) void {
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
                Action.rotate_cw => {
                    if (self.current != null) {
                        var piece = self.current.?;
                        const newOrientation = Direction.rotate_cw(piece.orientation);
                        piece.orientation = newOrientation;

                        if (self.isValidPiece(piece)) {
                            self.current.?.orientation = newOrientation;
                        }
                    }
                },
                Action.rotate_ccw => {
                    if (self.current != null) {
                        var piece = self.current.?;
                        const newOrientation = Direction.rotate_ccw(piece.orientation);
                        piece.orientation = newOrientation;

                        if (self.isValidPiece(piece)) {
                            self.current.?.orientation = newOrientation;
                        }
                    }
                },
                Action.hard_drop => {
                    if (self.current != null) {
                        var piece = self.current.?;
                        while (true) {
                            piece.position.y += 1;

                            if (!self.isValidPiece(piece)) {
                                self.current.?.position.y = piece.position.y - 1;
                                self.lockCurrentPiece();
                                break;
                            }
                        }
                    }
                },
                else => {},
            }
        }

        fn isValidPiece(self: *const Self, piece: DroppingPiece) bool {
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
}

const Game = GameG(randomizers.Bag(Tetromino));

test "Game#clone()" {
    const testTetromino = Tetromino{ .block = Block.s, .pattern = [4]Coordinate{
        Coordinate{ .x = 1, .y = 0 },
        Coordinate{ .x = 0, .y = 0 },
        Coordinate{ .x = 0, .y = -1 },
        Coordinate{ .x = 1, .y = -1 },
    } };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const tetrominos: []Tetromino = try allocator.alloc(Tetromino, 1);
    tetrominos[0] = testTetromino;
    const spec = GameSpec{ .dimensions = .{ .x = 10, .y = 22 } };
    const game = Game{
        .spec = spec,
        .state = GameState.running,
        .tetrominos = tetrominos,
        .rng = rng.LCG.init(123),
        .playfield = try allocator.alloc(Block, spec.totalCells()),
        .current = .{
            .tetromino = testTetromino,
            .orientation = Direction.north,
            .position = Coordinate{ .x = 5, .y = 1 },
        },
    };
    @memset(game.playfield, Block.none);

    var gameCopy = try game.clone(allocator);

    gameCopy.current.?.position.x = 3;
    try expect(game.current.?.position.x == 5);

    gameCopy.playfield[0] = Block.garbage;
    try expectEqual(Block.none, game.playfield[0]);

    const seed = game.rng.seed;
    _ = gameCopy.nextPiece();
    try expectEqual(seed, game.rng.seed);
}

pub fn main() void {
    run() catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
    };
}

fn writeFmt(out: anytype, comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, fmt, args);
    try out.writeAll(s);
}

fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var ai = AI{ .currentAction = Action.left, .rng = rng.LCG.init(0), .pendingActions = std.ArrayList(Action).empty };
    // Initialize debug log file (truncate at start)
    //var log_file = try std.fs.cwd().createFile("ai.log", .{ .truncate = true });
    //defer log_file.close();

    // Noop writer that discards all writes
    const NoopWriter = struct {
        const Self = @This();

        pub fn writeAll(self: Self, bytes: []const u8) !void {
            _ = self;
            _ = bytes;
            // Do nothing - this is a noop writer
        }
    };
    const log_file = NoopWriter{};
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
            Coordinate{ .x = -1, .y = 0 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 0, .y = -1 },
            Coordinate{ .x = 1, .y = -1 },
        },
    };

    tetrominos[6] = Tetromino{
        .block = Block.z,
        .pattern = [4]Coordinate{
            Coordinate{ .x = -1, .y = -1 },
            Coordinate{ .x = 0, .y = -1 },
            Coordinate{ .x = 0, .y = 0 },
            Coordinate{ .x = 1, .y = 0 },
        },
    };
    const randomizer = randomizers.Bag(Tetromino).init(allocator, 7, tetrominos);
    var game = try Game.init(allocator, tetrominos, randomizer);
    @memset(game.playfield, Block.none);
    game.current = .{
        .tetromino = game.nextPiece(),
        .orientation = Direction.north,
        .position = Coordinate{ .x = 5, .y = 1 },
    };

    while (game.state == GameState.running) {

        // Not in render so that we can dump debug stuff in update()
        const stdout = std.fs.File.stdout();
        _ = stdout.write("\x1b[2J\x1b[H") catch 0;

        //std.debug.print("AI STARTING\n", .{});
        if (game.current != null and game.current.?.position.y <= 1) {
            const potentialActions = [_][]const Action{
                &.{Action.left},
                &.{ Action.left, Action.left },
                &.{ Action.left, Action.left, Action.left },
                &.{ Action.left, Action.left, Action.left, Action.left },
                &.{Action.right},
                &.{ Action.right, Action.right },
                &.{ Action.right, Action.right, Action.right },
                &.{ Action.rotate_cw, Action.left },
                &.{ Action.rotate_cw, Action.left, Action.left },
                &.{ Action.rotate_cw, Action.left, Action.left, Action.left },
                &.{ Action.rotate_cw, Action.right },
                &.{ Action.rotate_cw, Action.right, Action.right },
                &.{ Action.rotate_cw, Action.right, Action.right, Action.right },
                &.{ Action.rotate_ccw, Action.left },
                &.{ Action.rotate_ccw, Action.left, Action.left },
                &.{ Action.rotate_ccw, Action.left, Action.left, Action.left },
                &.{ Action.rotate_ccw, Action.left, Action.left, Action.left, Action.left },
                &.{ Action.rotate_ccw, Action.right },
                &.{ Action.rotate_ccw, Action.right, Action.right },
                &.{ Action.rotate_ccw, Action.right, Action.right, Action.right },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.left },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.left, Action.left },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.left, Action.left, Action.left },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.left, Action.left, Action.left, Action.left },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.right },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.right, Action.right },
                &.{ Action.rotate_cw, Action.rotate_cw, Action.right, Action.right, Action.right },
            };

            var minErr: i32 = std.math.maxInt(i32);
            var bestAction: []const Action = &.{};

            for (potentialActions) |as| {
                var gameCopy = try game.clone(allocator);
                for (as) |a| {
                    gameCopy.apply(a);
                }
                gameCopy.apply(Action.hard_drop);

                var err: i32 = 0;
                if (gameCopy.state == GameState.halted) {
                    err = std.math.maxInt(i32);
                } else {
                    var heights = try allocator.alloc(usize, gameCopy.width());
                    var holes = try allocator.alloc(usize, gameCopy.height());
                    var heightTotal: i32 = 0;
                    @memset(heights, 0);
                    @memset(holes, 0);

                    for (0..@intCast(gameCopy.spec.dimensions.x)) |x| {
                        var foundHeight = false;
                        for (0..@intCast(gameCopy.spec.dimensions.y)) |y| {
                            const focus = Coordinate.fromU(x, y);
                            const block = gameCopy.at(focus);

                            if (foundHeight) {
                                if (block == Block.none) {
                                    holes[x] += 1;
                                }
                            } else {
                                if (block != Block.none) {
                                    foundHeight = true;
                                    heights[x] = gameCopy.height() - y;
                                    heightTotal += @intCast(heights[x]);
                                }
                            }
                        }
                    }

                    const averageHeight = @divFloor(heightTotal, @as(i32, @intCast(gameCopy.width())));
                    for (heights) |height| {
                        err += std.math.pow(i32, (@as(i32, @intCast(height)) - averageHeight), 2);
                    }
                    for (holes) |hole| {
                        err += @as(i32, @intCast(hole)) * 25;
                    }
                    // Debug logging for this candidate (use bufPrint + writeAll)
                    try writeFmt(log_file, "actions: {any}\n", .{as});
                    try writeFmt(log_file, "heights: {any}\n", .{heights});
                    try writeFmt(log_file, "holes: {any}\n", .{holes});
                }
                try writeFmt(log_file, "error: {d}\n", .{err});
                gameCopy.current = null;
                try render(gameCopy, log_file);
                try writeFmt(log_file, "\n\n", .{});
                if (err < minErr) {
                    minErr = err;
                    bestAction = as;
                }
            }

            var i = bestAction.len;
            while (i > 0) {
                i -= 1;
                try ai.pendingActions.append(allocator, bestAction[i]);
            }
        }
        //if (ai.pendingActions.pop()) |action| {
        //    game.apply(action);
        //}
        while (ai.pendingActions.pop()) |action| {
            game.apply(action);
        }
        //std.debug.print("REAL STARTING\n", .{});
        update(&game);
        std.debug.print("\n\n", .{});
        try render(game, stdout);
        std.Thread.sleep(1_000_000_00 / 4);
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
        game.lockCurrentPiece();
    }
}

fn render(game: Game, out: anytype) !void {
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

    try out.writeAll("----------\n");
    for (0..@as(u8, @intCast(spec.dimensions.y))) |y| {
        for (0..@as(u8, @intCast(spec.dimensions.x))) |x| {
            const idx = game.indexFor(.{ .x = @intCast(x), .y = @intCast(y) });
            const block = playfield_slice[idx];
            switch (block) {
                Block.none => {
                    try out.writeAll(" ");
                },
                else => {
                    try out.writeAll("█");
                },
            }
        }
        try out.writeAll("\n");
    }
    try out.writeAll("==========\n");
}

const std = @import("std");

// Simple Linear Congruential Generator (LCG)
// AI Generated.
//
// Using this rather than stdlib so can port to other languages and get
// deterministic results.
pub const LCG = struct {
    seed: i32,

    // Initialize with seed (uses current timestamp if seed is 0)
    pub fn init(seed: i32) LCG {
        var actual_seed = seed;
        if (actual_seed == 0) {
            actual_seed = @intCast(std.time.timestamp() & 0x7FFFFFFF);
        }

        // Keep within 32-bit signed int range
        // TODO: why is this necessary? (It was AI generated)
        actual_seed = @mod(actual_seed, 2147483647);
        if (actual_seed <= 0) actual_seed += 2147483646;

        return LCG{ .seed = actual_seed };
    }

    // Generate next random number (0 to 2147483646)
    pub fn next(self: *LCG) i32 {
        self.seed = @mod(self.seed *% 16807, 2147483647);
        return self.seed;
    }

    pub fn nextUint(self: *LCG) u32 {
        return @bitCast(self.next());
    }

    // Generate random float between 0 and 1 (exclusive)
    pub fn nextFloat(self: *LCG) f32 {
        return @as(f32, @floatFromInt(self.next() - 1)) / 2147483646.0;
    }

    // Generate random integer between min and max (inclusive)
    pub fn nextInt(self: *LCG, min: i32, max: i32) i32 {
        const range = max - min + 1;
        return @as(i32, @intFromFloat(self.nextFloat() * @as(f32, @floatFromInt(range)))) + min;
    }

    // Generate random boolean
    pub fn nextBool(self: *LCG) bool {
        return self.nextFloat() < 0.5;
    }

    // Reset seed
    pub fn setSeed(self: *LCG, seed: i32) void {
        self.seed = @mod(seed, 2147483647);
        if (self.seed <= 0) self.seed += 2147483646;
    }
};

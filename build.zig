const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const notcurses_source_path = "deps/notcurses";

    const notcurses_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // notcurses has saome undefined benavior which makes the demo crash with
        // illegal instruction, disabling UBSAN to make it work (-fno-sanitize-c)
        .sanitize_c = std.zig.SanitizeC.off,
    });
    const notcurses = b.addLibrary(.{
        .name = "notcurses",
        .root_module = notcurses_module,
    });

    // TODO: Reenable this
    //notcurses.disable_sanitize_c = true;
    notcurses.linkLibC();

    notcurses.addIncludePath(b.path(notcurses_source_path ++ "/include"));
    notcurses.addIncludePath(b.path(notcurses_source_path ++ "/build/include"));
    notcurses.addIncludePath(b.path(notcurses_source_path ++ "/src"));
    notcurses.addCSourceFiles(.{
        .files = &[_][]const u8{
            notcurses_source_path ++ "/src/compat/compat.c",

            notcurses_source_path ++ "/src/lib/automaton.c",
            notcurses_source_path ++ "/src/lib/banner.c",
            notcurses_source_path ++ "/src/lib/blit.c",
            notcurses_source_path ++ "/src/lib/debug.c",
            notcurses_source_path ++ "/src/lib/direct.c",
            notcurses_source_path ++ "/src/lib/fade.c",
            notcurses_source_path ++ "/src/lib/fd.c",
            notcurses_source_path ++ "/src/lib/fill.c",
            notcurses_source_path ++ "/src/lib/gpm.c",
            notcurses_source_path ++ "/src/lib/in.c",
            notcurses_source_path ++ "/src/lib/kitty.c",
            notcurses_source_path ++ "/src/lib/layout.c",
            notcurses_source_path ++ "/src/lib/linux.c",
            notcurses_source_path ++ "/src/lib/menu.c",
            notcurses_source_path ++ "/src/lib/metric.c",
            notcurses_source_path ++ "/src/lib/mice.c",
            notcurses_source_path ++ "/src/lib/notcurses.c",
            notcurses_source_path ++ "/src/lib/plot.c",
            notcurses_source_path ++ "/src/lib/progbar.c",
            notcurses_source_path ++ "/src/lib/reader.c",
            notcurses_source_path ++ "/src/lib/reel.c",
            notcurses_source_path ++ "/src/lib/render.c",
            notcurses_source_path ++ "/src/lib/selector.c",
            notcurses_source_path ++ "/src/lib/sixel.c",
            notcurses_source_path ++ "/src/lib/sprite.c",
            notcurses_source_path ++ "/src/lib/stats.c",
            notcurses_source_path ++ "/src/lib/tabbed.c",
            notcurses_source_path ++ "/src/lib/termdesc.c",
            notcurses_source_path ++ "/src/lib/tree.c",
            notcurses_source_path ++ "/src/lib/unixsig.c",
            notcurses_source_path ++ "/src/lib/util.c",
            notcurses_source_path ++ "/src/lib/visual.c",
            notcurses_source_path ++ "/src/lib/windows.c",
        },
        .flags = &[_][]const u8{
            "-std=gnu11",
            "-D_GNU_SOURCE", // to make memory management work, see sys/mman.h
            "-DUSE_MULTIMEDIA=none",
            "-DUSE_QRCODEGEN=OFF",
            "-DPOLLRDHUP=0x2000",
        },
    });

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_module.linkLibrary(notcurses);
    exe_module.linkSystemLibrary("qrcodegen", .{});
    exe_module.linkSystemLibrary("deflate", .{});
    // TODO: Presumably this is going to be needed...
    //exe_module.linkSystemLibrary("ncurses", .{});
    exe_module.linkSystemLibrary("readline", .{});
    exe_module.linkSystemLibrary("unistring", .{});
    exe_module.linkSystemLibrary("z", .{});

    const exe = b.addExecutable(.{
        .name = "tetrafall",
        .root_module = exe_module,
    });
    b.installArtifact(exe);
    exe.linkLibC();

    // exe.linkSystemLibrary("notcurses-core");
    // exe.addObjectFile(notcurses_source_path ++ "/build/libnotcurses-core.a");

    exe.addIncludePath(b.path(notcurses_source_path ++ "/include"));

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    exe.linkLibC();

    // exe.linkSystemLibrary("notcurses-core");
    // exe.addObjectFile(notcurses_source_path ++ "/build/libnotcurses-core.a");

    exe.addIncludePath(b.path(notcurses_source_path ++ "/include"));
    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &.{};
    const tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);
}

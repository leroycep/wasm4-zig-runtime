const std = @import("std");
const mach = @import("./zig-deps/mach/build.zig");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Convert charset.png into an array of bits to embed
    const charset_png_to_bits_exe = b.addExecutable("charset-png-to-bits", "tools/charset-png-to-bits.zig");
    charset_png_to_bits_exe.addPackagePath("zigimg", "zig-deps/zigimg/zigimg.zig");
    b.step("charset-png-to-bits", "Convert charset.png to a file containing raw bits").dependOn(&charset_png_to_bits_exe.run().step);

    const app = try mach.App.init(b, .{
        .name = "wasm4-zig-runtime",
        .src = "./src/main.zig",
        .target = target,
        .deps = &.{
            .{
                .name = "zware",
                .source = .{ .path = "zig-deps/zware/src/main.zig" },
            },
            .{
                .name = "zigimg",
                .source = .{ .path = "zig-deps/zigimg/zigimg.zig" },
            },
        },
    });
    try app.link(.{});
    app.install();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(try app.run());

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

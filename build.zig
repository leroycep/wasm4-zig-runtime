const fetch = @import("fetch.zig");
const std = @import("std");

const deps = [_]fetch.Dependency{
    .{
        .name = "zware",
        .vcs = .{
            .git = .{
                .url = "https://github.com/malcolmstill/zware.git",
                .commit = "7c1d909189e061601cab66235cf2830883d00aa2",
                .recursive = true,
            },
        },
    },
    .{
        .name = "mach",
        .vcs = .{
            .git = .{
                .url = "https://github.com/hexops/mach.git",
                .commit = "a2c6319bc4e99d034f89cd614426ea39e5de0a31",
                .recursive = true,
            },
        },
    },
    .{
        .name = "zigimg",
        .vcs = .{
            .git = .{
                .url = "https://github.com/zigimg/zigimg.git",
                .commit = "bbe433b385804fd7ba8a1bc23bac1a26798eebea",
                .recursive = true,
            },
        },
    },
};

pub fn build(builder: *std.build.Builder) !void {
    fetch.addStep(builder, "run", "Run example app");
    fetch.addStep(builder, "charset-png-to-bits", "Convert charset.png to a file containing raw bits");
    try fetch.fetchAndBuild(builder, "zig-deps", &deps, "compile.zig");
}

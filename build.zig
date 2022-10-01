const fetch = @import("fetch.zig");
const std = @import("std");

const deps = [_]fetch.Dependency{
    .{
        .name = "zware",
        .vcs = .{
            .git = .{
                .url = "https://github.com/malcolmstill/zware.git",
                .commit = "724e1669609dc2f41e904396257e0ff80cad1df6",
                .recursive = true,
            },
        },
    },
    .{
        .name = "mach",
        .vcs = .{
            .git = .{
                .url = "https://github.com/hexops/mach.git",
                .commit = "ec8ced475f0afdb4e213f1fa2191365d0db48978",
                .recursive = true,
            },
        },
    },
    .{
        .name = "zigimg",
        .vcs = .{
            .git = .{
                .url = "https://github.com/zigimg/zigimg.git",
                .commit = "fff6ea92a00c5f6092b896d754a932b8b88149ff",
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

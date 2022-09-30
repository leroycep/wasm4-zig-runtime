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
};

pub fn build(builder: *std.build.Builder) !void {
    fetch.addStep(builder, "run", "Run example app");
    try fetch.fetchAndBuild(builder, "zig-deps", &deps, "compile.zig");
}

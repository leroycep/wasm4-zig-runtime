const std = @import("std");
const zware = @import("zware");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cart_bytes = try std.fs.cwd().readFileAlloc(allocator, args[1], 65 * 1024 * 1024);
    defer allocator.free(cart_bytes);

    var store = zware.Store.init(allocator);
    // Drawing
    const blitSub_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32, .I32, .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4BlitSub },
        },
    });
    const line_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Line },
        },
    });
    const oval_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Oval },
        },
    });
    const rect_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Rect },
        },
    });
    const textUtf8_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4TextUtf8 },
        },
    });
    // Sound
    const tone_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Tone },
        },
    });
    // Storage
    const diskw_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{.I32},
        .subtype = .{
            .host_function = .{ .func = wasm4DiskW },
        },
    });
    const diskr_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{.I32},
        .subtype = .{
            .host_function = .{ .func = wasm4DiskR },
        },
    });
    // Debug
    const tracef_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Tracef },
        },
    });
    const traceUtf8_fn = try store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4TraceUtf8 },
        },
    });

    try store.@"export"("env", "blitSub", .Func, blitSub_fn);
    try store.@"export"("env", "line", .Func, line_fn);
    try store.@"export"("env", "oval", .Func, oval_fn);
    try store.@"export"("env", "rect", .Func, rect_fn);
    try store.@"export"("env", "textUtf8", .Func, textUtf8_fn);
    try store.@"export"("env", "tone", .Func, tone_fn);
    try store.@"export"("env", "diskr", .Func, diskr_fn);
    try store.@"export"("env", "diskw", .Func, diskw_fn);
    try store.@"export"("env", "tracef", .Func, tracef_fn);
    try store.@"export"("env", "traceUtf8", .Func, traceUtf8_fn);

    const memory_index = try store.addMemory(1, 1);
    try store.@"export"("env", "memory", .Mem, memory_index);

    var module = zware.Module.init(allocator, cart_bytes);
    try module.decode();

    var new_instance = zware.Instance.init(allocator, &store, module);
    const index = try store.addInstance(new_instance);
    var instance = try store.instance(index);
    try instance.instantiate(index);

    try instance.invoke("start", &.{}, &.{}, .{});
}

fn wasm4BlitSub(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4Line(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4Oval(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4Rect(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4TextUtf8(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4Tone(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4DiskR(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4DiskW(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
}
fn wasm4TraceUtf8(vm: *zware.VirtualMachine) zware.WasmError!void {
    const memory = try vm.inst.getMemory(0);
    const str_len = vm.popOperand(u32);
    const str_ptr = vm.popOperand(u32);
    std.log.debug("{s}", .{memory.asSlice()[str_ptr..][0..str_len]});
}
fn wasm4Tracef(vm: *zware.VirtualMachine) zware.WasmError!void {
    _ = vm;
    std.log.debug("Hi", .{});
}

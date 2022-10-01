const std = @import("std");
const zware = @import("zware");
const mach = @import("mach");
const gpu = mach.gpu;

pub const App = @This();

pipeline: *gpu.RenderPipeline,
vertex_buffer: *gpu.Buffer,
bind_group: *gpu.BindGroup,
framebuffer_texture: *gpu.Texture,

framebuffer_rgba: [160][160][4]u8,

arena: std.heap.ArenaAllocator,
store: zware.Store,
module: zware.Module,
instanceIndex: usize,

const Vertex = struct {
    pos: [2]f32,
    uv: [2]f32,
};

const VERTICES = [_]Vertex{
    .{ .pos = .{ -1.0, -1.0 }, .uv = .{ 0, 1 } },
    .{ .pos = .{ 1.0, -1.0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ -1.0, 1.0 }, .uv = .{ 0, 0 } },

    .{ .pos = .{ 1.0, -1.0 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ 1.0, 1.0 }, .uv = .{ 1, 0 } },
    .{ .pos = .{ -1.0, 1.0 }, .uv = .{ 0, 0 } },
};

pub fn init(app: *App, core: *mach.Core) !void {
    app.arena = std.heap.ArenaAllocator.init(core.allocator);
    const allocator = app.arena.allocator();

    const framebuffer_shader_module = core.device.createShaderModuleWGSL("frambuffer.wgsl", @embedFile("./framebuffer.wgsl"));
    defer framebuffer_shader_module.release();

    app.pipeline = core.device.createRenderPipeline(&.{
        .fragment = &gpu.FragmentState.init(.{
            .module = framebuffer_shader_module,
            .entry_point = "fragment",
            .targets = &.{
                gpu.ColorTargetState{
                    .format = core.swap_chain_format,
                    .blend = &.{},
                    .write_mask = gpu.ColorWriteMaskFlags.all,
                },
            },
        }),
        .vertex = gpu.VertexState.init(.{
            .module = framebuffer_shader_module,
            .entry_point = "vertex",
            .buffers = &.{
                gpu.VertexBufferLayout.init(.{
                    .array_stride = @sizeOf(Vertex),
                    .step_mode = .vertex,
                    .attributes = &[_]gpu.VertexAttribute{
                        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 },
                        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
                    },
                }),
            },
        }),
    });

    app.vertex_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true, .copy_dst = true },
        .size = VERTICES.len * @sizeOf(Vertex),
    });
    core.device.getQueue().writeBuffer(app.vertex_buffer, 0, &VERTICES);

    const sampler = core.device.createSampler(&.{
        .mag_filter = .nearest,
        .min_filter = .nearest,
    });

    app.framebuffer_texture = core.device.createTexture(&.{
        .size = gpu.Extent3D{ .width = 160, .height = 160 },
        .format = .rgba8_unorm,
        .usage = .{
            .texture_binding = true,
            .copy_dst = true,
            .render_attachment = true,
        },
    });

    app.bind_group = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = app.pipeline.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.sampler(0, sampler),
                gpu.BindGroup.Entry.textureView(1, app.framebuffer_texture.createView(&gpu.TextureView.Descriptor{})),
            },
        }),
    );

    // Load WASM4 cart
    const cart_bytes = try std.fs.cwd().readFileAlloc(allocator, "./cart.wasm", 65 * 1024 * 1024);

    app.store = zware.Store.init(allocator);
    // Drawing
    const blitSub_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32, .I32, .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4BlitSub },
        },
    });
    const line_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Line },
        },
    });
    const oval_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Oval },
        },
    });
    const rect_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Rect },
        },
    });
    const textUtf8_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4TextUtf8 },
        },
    });
    // Sound
    const tone_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32, .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Tone },
        },
    });
    // Storage
    const diskw_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{.I32},
        .subtype = .{
            .host_function = .{ .func = wasm4DiskW },
        },
    });
    const diskr_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{.I32},
        .subtype = .{
            .host_function = .{ .func = wasm4DiskR },
        },
    });
    // Debug
    const tracef_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4Tracef },
        },
    });
    const traceUtf8_fn = try app.store.addFunction(.{
        .params = &.{ .I32, .I32 },
        .results = &.{},
        .subtype = .{
            .host_function = .{ .func = wasm4TraceUtf8 },
        },
    });

    try app.store.@"export"("env", "blitSub", .Func, blitSub_fn);
    try app.store.@"export"("env", "line", .Func, line_fn);
    try app.store.@"export"("env", "oval", .Func, oval_fn);
    try app.store.@"export"("env", "rect", .Func, rect_fn);
    try app.store.@"export"("env", "textUtf8", .Func, textUtf8_fn);
    try app.store.@"export"("env", "tone", .Func, tone_fn);
    try app.store.@"export"("env", "diskr", .Func, diskr_fn);
    try app.store.@"export"("env", "diskw", .Func, diskw_fn);
    try app.store.@"export"("env", "tracef", .Func, tracef_fn);
    try app.store.@"export"("env", "traceUtf8", .Func, traceUtf8_fn);

    const memory_index = try app.store.addMemory(1, 1);
    try app.store.@"export"("env", "memory", .Mem, memory_index);

    var module = zware.Module.init(allocator, cart_bytes);
    try module.decode();

    app.instanceIndex = try app.store.addInstance(zware.Instance.init(allocator, &app.store, module));
    const instance = try app.store.instance(app.instanceIndex);
    try instance.instantiate(app.instanceIndex);

    const instance_memory = try instance.getMemory(0);
    const memory = instance_memory.asSlice();

    const palette = @ptrCast([*]u32, @alignCast(4, memory[PALETTE..].ptr))[0..4];
    palette.* = .{
        0xfff6d3,
        0xf9a875,
        0xeb6b6f,
        0x7c3f58,
    };

    try instance.invoke("start", &.{}, &.{}, .{});
}

pub fn deinit(app: *App, core: *mach.Core) void {
    app.arena.deinit();
    _ = core;
}

const GamePad = packed struct(u8) {
    button_1: bool,
    button_2: bool,
    _unused: u2,
    left: bool,
    right: bool,
    up: bool,
    down: bool,
};

pub fn update(app: *App, core: *mach.Core) !void {
    const instance = try app.store.instance(app.instanceIndex);
    const instance_memory = try instance.getMemory(0);
    const memory = instance_memory.asSlice();

    const gamepads = @ptrCast(*[4]GamePad, memory[GAMEPADS..][0..GAMEPADS_SIZE]);
    while (core.pollEvent()) |event| {
        switch (event) {
            .key_press => |ev| switch (ev.key) {
                .left => gamepads[0].left = true,
                .right => gamepads[0].right = true,
                .up => gamepads[0].up = true,
                .down => gamepads[0].down = true,
                .z => gamepads[0].button_1 = true,
                .x => gamepads[0].button_2 = true,
                else => {},
            },
            .key_release => |ev| switch (ev.key) {
                .left => gamepads[0].left = false,
                .right => gamepads[0].right = false,
                .up => gamepads[0].up = false,
                .down => gamepads[0].down = false,
                .z => gamepads[0].button_1 = false,
                .x => gamepads[0].button_2 = false,
                else => {},
            },
            else => {},
        }
    }

    try instance.invoke("update", &.{}, &.{}, .{
        .operand_stack_size = 4096,
    });

    const back_buffer_view = core.swap_chain.?.getCurrentTextureView();
    defer back_buffer_view.release();

    const palette = @ptrCast([*]align(4) u24, @alignCast(4, memory[PALETTE..].ptr))[0..4];
    const framebuffer = memory[FRAMEBUFFER..][0..6400];

    // Upload framebuffer to gpu
    {
        // Convert framebuffer to RGBA
        var y: u16 = 0;
        while (y < 160) : (y += 1) {
            var x: u16 = 0;
            while (x < 160) : (x += 1) {
                const color_index = @truncate(u2, framebuffer[(y * 160 + x) / 4] >> @intCast(u3, (x & 0x03) * 2));
                const color = palette[color_index];
                app.framebuffer_rgba[y][x] = .{
                    @truncate(u8, color),
                    @truncate(u8, color >> 8),
                    @truncate(u8, color >> 16),
                    0xFF,
                };
            }
        }
        core.device.getQueue().writeTexture(
            &.{ .texture = app.framebuffer_texture },
            &.{
                .bytes_per_row = 160 * 4,
                .rows_per_image = 160,
            },
            &.{ .width = 160, .height = 160 },
            &app.framebuffer_rgba,
        );
    }

    const encoder = core.device.createCommandEncoder(null);
    defer encoder.release();

    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{
            .{
                .view = back_buffer_view,
                .clear_value = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 0.0 },
                .load_op = .clear,
                .store_op = .store,
            },
        },
    }));
    defer render_pass.release();

    render_pass.setPipeline(app.pipeline);
    render_pass.setVertexBuffer(0, app.vertex_buffer, 0, @sizeOf(Vertex) * VERTICES.len);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.draw(VERTICES.len, 1, 0, 0);
    render_pass.end();

    const command = encoder.finish(null);
    core.device.getQueue().submit(&.{command});
    core.swap_chain.?.present();
}

const PALETTE = 0x0004;
const FRAMEBUFFER = 0x00a0;
const FRAMEBUFFER_SIZE = 6400;
const DRAW_COLORS = 0x0014;
const GAMEPADS = 0x0016;
const GAMEPADS_SIZE = 4;

const FONT = @embedFile("charset.bits");
const FONT_WIDTH = 128;
const FONT_HEIGHT = 112;
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;

fn wasm4BlitSub(vm: *zware.VirtualMachine) zware.WasmError!void {
    const flags = vm.popOperand(u32);
    const height = vm.popOperand(u32);
    const width = vm.popOperand(u32);
    const y = vm.popOperand(u32);
    const x = vm.popOperand(u32);
    const sprite_ptr = vm.popOperand(u32);

    std.log.debug("blitSub {} {} {} {} {} {}", .{ sprite_ptr, x, y, width, height, flags });
}
fn wasm4Line(vm: *zware.VirtualMachine) zware.WasmError!void {
    const memory = try vm.inst.getMemory(0);

    const draw_colors = std.mem.readIntLittle(u16, memory.asSlice()[DRAW_COLORS..][0..2]);
    const fill_color: u2 = if (draw_colors & 0x0F > 0) @intCast(u2, (draw_colors & 0x0F) - 1) else return;
    const framebuffer = memory.asSlice()[FRAMEBUFFER..][0..FRAMEBUFFER_SIZE];

    const y2 = vm.popOperand(i32);
    const x2 = vm.popOperand(i32);
    const y1 = vm.popOperand(i32);
    const x1 = vm.popOperand(i32);

    const dx = try std.math.absInt(x2 - x1);
    const sx: i32 = if (x1 < x2) 1 else -1;
    const dy = -try std.math.absInt(y2 - y1);
    const sy: i32 = if (y1 < y2) 1 else -1;

    var err = dx + dy;
    var x = x1;
    var y = y1;
    while (true) {
        if (x > 0 and x < 160 and y > 0 and y < 160) setPixel(framebuffer, @intCast(u32, x), @intCast(u32, y), fill_color);
        if (x == x2 and y == y2) break;
        const err2 = 2 * err;
        if (err2 >= dy) {
            if (x == x2) break;
            err += dy;
            x += sx;
        }
        if (err2 <= dx) {
            if (y == x2) break;
            err += dx;
            y += sy;
        }
    }
}
fn wasm4Oval(vm: *zware.VirtualMachine) zware.WasmError!void {
    const height = vm.popOperand(u32);
    const width = vm.popOperand(u32);
    const y = vm.popOperand(u32);
    const x = vm.popOperand(u32);

    std.log.debug("oval {} {} {} {}", .{ x, y, width, height });
}
fn wasm4Rect(vm: *zware.VirtualMachine) zware.WasmError!void {
    const memory = try vm.inst.getMemory(0);

    const draw_colors = std.mem.readIntLittle(u16, memory.asSlice()[DRAW_COLORS..][0..2]);
    const fill_color: u2 = if (draw_colors & 0x0F > 0) @intCast(u2, (draw_colors & 0x0F) - 1) else return;
    const framebuffer = memory.asSlice()[FRAMEBUFFER..][0..FRAMEBUFFER_SIZE];

    const height = vm.popOperand(u32);
    const width = vm.popOperand(u32);
    const y = vm.popOperand(u32);
    const x = vm.popOperand(u32);

    var j = y;
    while (j < y + height) : (j += 1) {
        var i = x;
        while (i < x + width) : (i += 1) {
            setPixel(framebuffer, i, j, fill_color);
        }
    }
}

fn wasm4TextUtf8(vm: *zware.VirtualMachine) zware.WasmError!void {
    const memory = try vm.inst.getMemory(0);

    const draw_colors = std.mem.readIntLittle(u16, memory.asSlice()[DRAW_COLORS..][0..2]);
    const text_color: ?u2 = if (draw_colors & 0x0F > 0) @intCast(u2, (draw_colors & 0x0F) - 1) else null;
    const background_color: ?u2 = if (draw_colors & 0xF0 > 0) @intCast(u2, ((draw_colors & 0xF0) >> 4) - 1) else null;
    const framebuffer = memory.asSlice()[FRAMEBUFFER..][0..FRAMEBUFFER_SIZE];

    const y = vm.popOperand(u32);
    const x = vm.popOperand(u32);
    const str_len = vm.popOperand(u32);
    const str_ptr = vm.popOperand(u32);

    const str = memory.asSlice()[str_ptr..][0..str_len];
    var pos = [2]u32{ x, y };
    for (str) |char| {
        if (char == '\n') {
            pos[0] = x;
            pos[1] += FONT_CHAR_HEIGHT;
            continue;
        }

        const char_y = ((char - 0x20) / 16) * FONT_CHAR_HEIGHT;
        const char_x = ((char - 0x20) % 16) * FONT_CHAR_WIDTH;

        var j: u32 = 0;
        while (j < FONT_CHAR_HEIGHT) : (j += 1) {
            var i: u32 = 0;
            while (i < FONT_CHAR_WIDTH) : (i += 1) {
                if (pos[0] + i >= 160 or pos[1] + j >= 160) continue;
                const is_text_pixel = FONT[(char_y + j) * FONT_WIDTH + (char_x + i)];
                if (is_text_pixel == 1) {
                    if (text_color) |color| {
                        setPixel(framebuffer, pos[0] + i, pos[1] + j, color);
                    }
                } else {
                    if (background_color) |color| {
                        setPixel(framebuffer, pos[0] + i, pos[1] + j, color);
                    }
                }
            }
        }
        pos[0] += FONT_CHAR_WIDTH;
    }
}

fn setPixel(framebuffer: []u8, x: u32, y: u32, color: u2) void {
    framebuffer[(y * 160 + x) / 4] &= ~(@as(u8, 0b11) << @intCast(u3, (x & 0b11) * 2));
    framebuffer[(y * 160 + x) / 4] |= @as(u8, color) << @intCast(u3, (x & 0b11) * 2);
}

fn wasm4Tone(vm: *zware.VirtualMachine) zware.WasmError!void {
    const flags = vm.popOperand(u32);
    const volume = vm.popOperand(u32);
    const duration = vm.popOperand(u32);
    const frequency = vm.popOperand(u32);
    std.log.debug("tone {} {} {} {}", .{ frequency, duration, volume, flags });
}
fn wasm4DiskR(vm: *zware.VirtualMachine) zware.WasmError!void {
    const size = vm.popOperand(u32);
    const dest_ptr = vm.popOperand(u32);
    std.log.debug("diskr {} {}", .{ dest_ptr, size });
}
fn wasm4DiskW(vm: *zware.VirtualMachine) zware.WasmError!void {
    const size = vm.popOperand(u32);
    const src_ptr = vm.popOperand(u32);
    std.log.debug("diskw {} {}", .{ src_ptr, size });
}
fn wasm4TraceUtf8(vm: *zware.VirtualMachine) zware.WasmError!void {
    const memory = try vm.inst.getMemory(0);
    const str_len = vm.popOperand(u32);
    const str_ptr = vm.popOperand(u32);
    std.log.debug("{s}", .{memory.asSlice()[str_ptr..][0..str_len]});
}
fn wasm4Tracef(vm: *zware.VirtualMachine) zware.WasmError!void {
    const instance_memory = try vm.inst.getMemory(0);
    const memory = instance_memory.asSlice();

    const stack_ptr = vm.popOperand(u32);
    const str_ptr = vm.popOperand(u32);

    const str_len = std.mem.indexOfScalar(u8, memory[str_ptr..], 0) orelse memory[str_ptr..].len;
    const str = memory[str_ptr..][0..str_len];

    std.log.debug("{s} {}", .{ str, stack_ptr });
}

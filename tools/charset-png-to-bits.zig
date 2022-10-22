const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var img = try zigimg.Image.fromFilePath(gpa.allocator(), "src/charset.png");
    defer img.deinit();

    const pixels = try gpa.allocator().alloc(u8, img.width * img.height);
    defer gpa.allocator().free(pixels);

    var pixel_iter = img.iterator();
    var i: usize = 0;
    while (pixel_iter.next()) |pixel| {
        if (pixel.r > 0.5) {
            pixels[i] = 1;
        } else {
            pixels[i] = 0;
        }
        i += 1;
    }

    try std.fs.cwd().writeFile("src/charset.bits", pixels);
    std.debug.print("width = {}, height = {}\n", .{ img.width, img.height });
}

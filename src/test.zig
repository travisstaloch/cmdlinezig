const std = @import("std");
const warn = std.debug.warn;
const clp = @import("parser.zig");

const Args = struct {
    name: []const u8 = "<name>", // @Cleanup free std.mem.dupe'd slices like this
    windowed: bool = false,
    width: u16 = 0,
    x: f32 = 0,
    xs: [10]i8 = [1]i8{0} ** 10,
    u8s: [2]u8 = [1]u8{0} ** 2,
    // t: ?[]u16 = null, // not yet supported
};

pub fn main() anyerror!void {
    var buf: [1024 * 4]u8 = undefined;
    const a = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;

    var args = try clp.ArgParser(Args).init(a);
    defer args.available.deinit();
    // @Cleanup free std.mem.dupe'd slices
    try args.parse(a);

    if (true) {
        warn("args: {}\n", args.values);
        args.show();
        warn("name provided {}\n", args.available.get("name").?.value);
    }
}

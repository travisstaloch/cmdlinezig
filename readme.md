## Simple command line parsing

Based on a user defined struct.

```zig
// src/test.zig
const std = @import("std");
const warn = std.debug.warn;
const clp = @import("parser.zig");

const Args = struct {
    name: []const u8 = "<name>",
    windowed: bool = false,
    width: u16 = 0,
    x: f32 = 0,
    xs: [10]i8 = [1]i8{0} ** 10,
    u8s: [2]u8 = [1]u8{0} ** 2,
};

pub fn main() anyerror!void {
    var buf: [1024 * 4]u8 = undefined;
    const a = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;

    var args = try clp.ArgParser(Args).init(a);
    defer args.available.deinit();
    try args.parse(a);

    warn("args: {}\n", args.values);
    args.show();
    warn("name provided {}\n", args.available.get("name").?.value);
}

```

```bash
$ zig run src/test.zig -- -xs 1 2 -u8s 1 2 3 4 --x -45 -name "my name"
args: Args{ .name = my name, .windowed = false, .width = 0, .x = -4.5e+01, .xs = i8@7fff092f7730, .u8s =  }
name: my name
x: -4.5e+01
xs: 1, 2, 0, 0, 0, 0, 0, 0, 0, 0,
u8s: 1, 2,
name provided true
```

```bash
$ zig build && ./zig-cache/bin/cmdlineparse -x -45
args: Args{ .name = <name>, .windowed = false, .width = 0, .x = -4.5e+01, .xs = i8@7ffe165b87a0, .u8s =  }
x: -4.5e+01
name provided false
```

You must provide default values for each field of the Args struct as it will be instantiated with no arguments like: `Args{}`.

The parser is quite lenient in what it will accept:
 - Duplicate arguments are ignored.  Only the first value will be used.
 - Extra arguments are ignored.
 - Argument names are case sensitive.
 - Arguments may be provided with one or two hyphens (ie -a and --a are the same).
 - Array arguments: any number of values may be provided and only the first array.len will be applied.  The rest are ignored.
 - If an argument is provided and valid, args.available.get("field_name").?.value will be set to true, otherwise false.
   - Empty array arguments are valid.

Argument supported types: Int, Float, Bool, Array, Slice of u8 (string)

Array supported types: Int, Float, Bool


### TODO
 - [ ] @Cleanup free std.mem.dupe'd slices
 - [ ] Maybe support slice types other than strings
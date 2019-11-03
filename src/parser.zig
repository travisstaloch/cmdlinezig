const std = @import("std");
const warn = std.debug.warn;
const builtin = @import("builtin");
const TypeId = builtin.TypeId;

pub fn ArgParser(comptime T: type) type {
    return struct {
        values: T,
        available: std.StringHashMap(bool),

        const Self = @This();
        const memberCt = @memberCount(T);

        pub fn init(a: *std.mem.Allocator) !Self {
            var self = Self{
                .values = T{},
                .available = std.StringHashMap(bool).init(a),
            };

            inline for (@typeInfo(T).Struct.fields) |f| {
                _ = try self.available.put(f.name, false);
            }

            return self;
        }

        pub fn parse(self: *Self, a: *std.mem.Allocator) !void {
            // Loop over user struct member names and look for case sensitive matching
            // names on command line, optionally stripping leading hyphens.
            // Have to do this the inefficient, hard way in order to have comptime
            // known i for @memberType(T, i)
            var buf: [1024]u8 = undefined;
            const fa = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;
            const args = try std.process.argsAlloc(fa);
            defer std.process.argsFree(fa, args);

            inline for (@typeInfo(T).Struct.fields) |f, i| {
                const fieldName = f.name;
                var arg_idx = blk: {
                    var j = usize(0);
                    while (j < args.len) : (j += 1) {
                        var arg = args[j];
                        // strip off one or two hyphens
                        if (arg[0] == '-') arg = arg[1..];
                        if (arg[0] == '-') arg = arg[1..];
                        if (std.mem.eql(u8, arg, fieldName)) {
                            break :blk j;
                        }
                    }
                    break :blk std.math.maxInt(usize);
                };

                if (arg_idx < args.len) {
                    arg_idx += 1;
                    // * i has to be comptime known here
                    const typ = @memberType(T, i);
                    const ti = @typeInfo(typ);
                    switch (ti) {
                        TypeId.Float => {
                            @field(self.values, fieldName) = try std.fmt.parseFloat(typ, args[arg_idx]);
                        },
                        TypeId.Int => {
                            @field(self.values, fieldName) = try std.fmt.parseInt(typ, args[arg_idx], 10);
                        },
                        TypeId.Bool => {
                            @field(self.values, fieldName) = true;
                        },
                        TypeId.Array => {
                            const cti = @typeInfo(typ.Child);
                            var fi = usize(0);
                            while (fi < typ.len and arg_idx + fi < args.len) : (fi += 1) {
                                switch (cti) {
                                    TypeId.Float => {
                                        @field(self.values, fieldName)[fi] = std.fmt.parseFloat(typ.Child, args[arg_idx + fi]) catch break;
                                    },
                                    TypeId.Int => {
                                        @field(self.values, fieldName)[fi] = std.fmt.parseInt(typ.Child, args[arg_idx + fi], 10) catch break;
                                    },
                                    TypeId.Bool => {
                                        @field(self.values, fieldName)[fi] = std.fmt.parseBool(args[arg_idx + fi], 10) catch break;
                                    },
                                    else => {
                                        warn("ERROR: unsupported array type " ++ @typeName(tpy.Child) ++ "\n");
                                        break;
                                    },
                                }
                            }
                        },

                        TypeId.Pointer => {
                            switch (ti.Pointer.size) {
                                builtin.TypeInfo.Pointer.Size.Slice => {
                                    @field(self.values, fieldName) = try std.mem.dupe(a, ti.Pointer.child, args[arg_idx]);
                                },
                                builtin.TypeInfo.Pointer.Size.One,
                                builtin.TypeInfo.Pointer.Size.Many,
                                builtin.TypeInfo.Pointer.Size.C,
                                => {
                                    warn("ERROR: unsupported non-slice pointer type found\n");
                                    continue;
                                },
                            }
                        },
                        else => {
                            warn("ERROR: unsupported type " ++ @typeName(typ) ++ " ignored\n");
                        },
                    }
                    _ = try self.available.put(fieldName, true);
                }
            }
        }

        pub fn show(self: Self) void {
            inline for (@typeInfo(T).Struct.fields) |f| {
                const fieldName = f.name;
                var me = self.available.get(fieldName);
                if (me) |e| {
                    if (e.value) {
                        switch (@typeInfo(f.field_type)) {
                            TypeId.Array => {
                                warn(fieldName ++ ": ");
                                for (@field(self.values, fieldName)) |x| warn("{}, ", x);
                                warn("\n");
                            },
                            else => {
                                warn("{}: {}\n", e.key, @field(self.values, fieldName));
                            },
                        }
                    }
                }
            }
        }
    };
}

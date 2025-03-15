const std = @import("std");
const g = @import("../root.zig");
const scene = g.canvas;

fn _LOGF(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void { //TODO: remove
    g.platform.log(std.fmt.allocPrint(allocator, fmt, args) catch unreachable);
}

pub fn AnimationManager(comptime vertex: type) type {
    return struct {
        const Self = @This();
        const Context = Ctx(vertex);
        const delay = 30;
        const frames = 25;

        program: g.Program,
        pool: Pool(Context),
        ctx: ?Context = null,
        next: usize = 0,

        pub fn init(
            allocator: std.mem.Allocator,
            program: g.Program,
        ) Self {
            return .{
                .pool = Pool(Context).init(allocator),
                .program = program,
            };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn context(
            allocator: std.mem.Allocator,
            idxs: []const u32,
            counts: u32,
            slices: SliceTuple(vertex),
        ) Ctx(vertex) {
            return Ctx(vertex).init(
                allocator,
                idxs,
                counts >> 0x10,
                counts & 0xFFFF,
                slices,
            );
        }

        pub fn start(
            _: *Self,
            fn_ptr: usize,
            args: []const u8,
        ) void {
            _ = g.Interval.init(@intCast(fn_ptr), args, delay, frames);
        }

        pub fn animate(self: *Self, geoc: g.Geoc, ctx: Ctx(vertex), args: anytype, transform: Trasform) void {
            switch (transform) {
                Trasform.Translate => {
                    // g.platform.log("switch translate");
                    const stepx = args[0] / frames;
                    const stepy = args[1] / frames;
                    const stepz = args[2] / frames;
                    if (ctx.copied.@"0") |vecs| {
                        var i: usize = 0;
                        while (i < vecs.len) : (i += 2) {
                            _LOGF(geoc.allocator, "steps: {} {} {}\n {} \n{any}", .{ stepx, stepy, stepz, self.next, vecs[i] });
                            vecs[i].coords[0] += stepx;
                            vecs[i].coords[1] += stepy;
                            vecs[i].coords[2] += stepz;
                        }
                    }

                    // self.translate(geoc, ctx, args);
                },
                Trasform.Rotate => {
                    // self.rotate(geoc, ctx, args);
                },
                Trasform.Scale => {
                    // self.scale(geoc, ctx, args);
                },
            }
            ctx.updateBuffers();

            self.program.use();

            if (ctx.buffers.@"0") |buff| {
                geoc.draw(vertex, self.program, buff, g.DrawMode.LineLoop);
            }
            if (ctx.buffers.@"1") |buff| {
                geoc.draw(vertex, self.program, buff, g.DrawMode.TriangleFan);
            }
            if (ctx.buffers.@"2") |buff| {
                geoc.draw(vertex, self.program, buff, g.DrawMode.LineLoop);
            }
            g.platform.log("draw");

            self.next += 1;
        }

        pub fn remove(self: *Self, vec: vertex) void {
            self.pool.delete(vec);
        }

        pub fn clear(self: *Self) void {
            while (self.pool.free.popFirst()) |node| {
                node.data.deinit();
                self.pool.delete(&node.data);
            }
            self.ctx.?.free(self.pool.arena.allocator());
            self.ctx = null;
            self.next = 0;
        }
    };
}

fn SliceTuple(comptime vertex: type) type {
    return struct {
        ?[]vertex,
        ?[][]vertex,
        ?[]struct { vertex },
    };
}

pub fn Ctx(comptime vertex: type) type {
    const OriginalSlicesTuple = SliceTuple(vertex);
    const CopiedSlicesTuple = struct { ?[]vertex, ?[]vertex, ?[]vertex };
    const AnimationBufferTuple = struct { ?g.VertexBuffer(vertex), ?g.VertexBuffer(vertex), ?g.VertexBuffer(vertex) };
    return struct {
        const Self = @This();

        buffers: AnimationBufferTuple,
        copied: CopiedSlicesTuple,
        slices: OriginalSlicesTuple,
        idxs: []const u32,

        pub fn init(
            allocator: std.mem.Allocator,
            idxs: []const u32,
            vector_count: usize,
            shape_count: usize,
            slices: OriginalSlicesTuple,
        ) Self {
            var copied = CopiedSlicesTuple{
                allocator.alloc(vertex, vector_count * 2) catch unreachable,
                null,
                null,
                // allocator.alloc(struct { vertex }, idxs.len - vector_count - shape_count) catch unreachable,
            };

            for (0..vector_count) |i| {
                copied.@"0".?[i * 2] = slices.@"0".?[idxs[i]];
                copied.@"0".?[i * 2 + 1] = slices.@"0".?[idxs[i] + 1];
            }

            var shapes_copy = allocator.alloc([]vertex, shape_count) catch unreachable;
            defer {
                for (shapes_copy) |shape| {
                    allocator.free(shape);
                }
                allocator.free(shapes_copy);
            }

            for (vector_count..vector_count + shape_count) |i| {
                shapes_copy[i - vector_count] = allocator.alloc(vertex, slices.@"1".?[idxs[i]].len) catch unreachable;
                for (slices.@"1".?[idxs[i]], 0..) |vector, j| {
                    shapes_copy[i - vector_count][j] = vector;
                }
            }

            // copied.@"1" = std.mem.concat(allocator, vertex, shapes_copy) catch unreachable;

            // for (vector_count + shape_count..idxs.len) |i| {
            //     copied.@"2".?[i - vector_count - shape_count] = slices.@"2".?[idxs[i]];
            // }

            const buffers = .{
                if (copied.@"0") |vectors| g.VertexBuffer(vertex).init(
                    vectors,
                    g.BufferUsage.DynamicDraw,
                ) else null,
                if (copied.@"1") |shapes| g.VertexBuffer(vertex).init(
                    shapes,
                    g.BufferUsage.DynamicDraw,
                ) else null,
                null,
            };

            return .{
                .copied = copied,
                .slices = slices,
                .buffers = buffers,
                .idxs = idxs,
            };
        }

        pub fn deinit(self: *align(1) const Self, allocator: std.mem.Allocator) void {
            self.buffers.@"0".?.deinit();
            self.buffers.@"1".?.deinit();
            self.buffers.@"2".?.deinit();
            self.free(allocator);
        }

        pub fn updateBuffers(self: *const Self) void {
            if (self.copied.@"0") |vecs| {
                self.buffers.@"0".?.bufferData(vecs, g.BufferUsage.DynamicDraw);
                // _LOGF(std.heap.page_allocator, "COPIED: {any}", .{.{vecs[0]}});
            }
            if (self.copied.@"1") |shapes| {
                self.buffers.@"1".?.bufferData(shapes, g.BufferUsage.DynamicDraw);
            }
            if (self.copied.@"2") |camera_pos| {
                self.buffers.@"2".?.bufferData(camera_pos, g.BufferUsage.DynamicDraw);
            }
        }

        pub fn updateStaticVertexData(self: *align(1) const Self) void {
            if (self.slices.@"0") |vecs| {
                for (self.idxs, 0..) |idx, i| {
                    vecs[idx] = self.copied.@"0".?[i * 2];
                    vecs[idx + 1] = self.copied.@"0".?[i * 2 + 1];
                }
            }
        }

        pub fn free(self: *align(1) const Self, allocator: std.mem.Allocator) void {
            _LOGF(allocator, "FREE\n{}", .{self.*});
            if (self.copied.@"0") |vecs| allocator.free(vecs);
            if (self.copied.@"1") |shapes| allocator.free(shapes);
            if (self.copied.@"2") |camera_pos| allocator.free(camera_pos);
        }
    };
}

pub const Trasform = enum(u8) {
    Translate,
    Rotate,
    Scale,
};

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();
        const List = std.SinglyLinkedList(T);

        arena: std.heap.ArenaAllocator,
        free: List,

        pub fn init(
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .arena = std.heap.ArenaAllocator.init(allocator),
                .free = .{},
            };
        }

        pub fn deinit(
            self: *Self,
        ) void {
            self.arena.deinit();
        }

        pub fn new(self: *Self) *T {
            const obj = if (self.free.popFirst()) |node|
                &node.data
            else
                self.arena.allocator().create(T) catch unreachable;
            return obj;
        }

        pub fn delete(self: *Self, obj: *T) void {
            const node: List.Node = @fieldParentPtr("data", obj);
            self.free.prepend(node);
        }
    };
}

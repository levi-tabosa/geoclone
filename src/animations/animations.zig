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
        const DELAY = 30;
        const FRAMES = 25;

        program: g.Program,
        pool: Pool(Context),
        ctx: ?Context = null,
        count: usize = 0,

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
            slices: SceneSlicesTuple(vertex),
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
            _ = g.Interval.init(@intCast(fn_ptr), args, DELAY, FRAMES);
        }

        pub fn animate(self: *Self, geoc: g.Geoc, ctx: Ctx(vertex), args: anytype, transform: Trasform) void {
            const allocator = self.pool.arena.allocator();
            const applied = struct { ?[]vertex, ?[]vertex, ?[]vertex }{
                if (ctx.copied.@"0") |vecs| allocator.alloc(vertex, vecs.len) catch unreachable else null,
                if (ctx.copied.@"1".?.len > 0) allocator.alloc(vertex, ctx.copied.@"1".?.len) catch unreachable else null,
                if (ctx.copied.@"2") |cams| allocator.alloc(vertex, cams.len) catch unreachable else null,
            };
            defer {
                if (applied.@"0") |vecs| allocator.free(vecs);
                if (applied.@"1") |shapes| allocator.free(shapes);
                if (applied.@"2") |cams| allocator.free(cams);
            }
            switch (transform) {
                Trasform.Translate => {
                    const stepx = args[0] / FRAMES * @as(f32, @floatFromInt(self.count));
                    const stepy = args[1] / FRAMES * @as(f32, @floatFromInt(self.count));
                    const stepz = args[2] / FRAMES * @as(f32, @floatFromInt(self.count));
                    if (ctx.copied.@"0") |vecs_copy| {
                        var i: usize = 0;
                        while (i < vecs_copy.len) : (i += 2) {
                            ctx.applied.@"0".?[i].coords[0] = vecs_copy[i].coords[0] + stepx;
                            ctx.applied.@"0".?[i].coords[1] = vecs_copy[i].coords[1] + stepy;
                            ctx.applied.@"0".?[i].coords[2] = vecs_copy[i].coords[2] + stepz;
                            applied.@"0".?[i] = ctx.applied.@"0".?[i].*;

                            _LOGF(allocator, "i : {d} count: {d} \n {any} {any}", .{ i, self.count, applied.@"0".?[i].coords, applied.@"0".?[i + 1].coords });
                        }
                    }
                },
                Trasform.Rotate => {
                    // self.rotate(geoc, ctx, args);
                },
                Trasform.Scale => {
                    // self.scale(geoc, ctx, args);
                },
            }
            ctx.updateBuffers(applied);

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

            self.count += 1;
        }

        pub fn remove(self: *Self, vec: vertex) void {
            self.pool.delete(vec);
        }

        pub fn clear(self: *Self) void {
            while (self.pool.free.popFirst()) |node| {
                node.data.deinit();
                self.pool.delete(&node.data);
            }
            // self.ctx.?.slices.@"0".?[]
            self.ctx.?.freeCopies(self.pool.arena.allocator());
            self.ctx = null;
            self.count = 0;
        }
    };
}

pub fn SceneSlicesTuple(comptime T: type) type {
    return struct {
        ?[]T,
        ?[][]T,
        ?[]struct { T },
    };
}

fn Tuple(comptime T: type) type {
    return struct {
        T,
        T,
        T,
    };
}

pub fn Ctx(comptime vertex: type) type {
    const SlicesTuple = SceneSlicesTuple(vertex);
    const CopiesTuple = Tuple(?[]vertex);
    const AppliesTuple = Tuple(?[]*vertex);
    const BufferTuple = Tuple(?g.VertexBuffer(vertex));
    return struct {
        const Self = @This();

        slices: SlicesTuple,
        buffers: BufferTuple,
        copied: CopiesTuple,
        applied: AppliesTuple,

        pub fn init(
            allocator: std.mem.Allocator,
            idxs: []const u32,
            vector_count: usize,
            shape_count: usize,
            slices: SlicesTuple,
        ) Self {
            var copied = CopiesTuple{
                null,
                null,
                null,
            };
            var applied = AppliesTuple{
                null,
                null,
                null,
            };

            if (vector_count > 0) {
                copied.@"0" = allocator.alloc(vertex, vector_count * 2) catch unreachable;
                applied.@"0" = allocator.alloc(*vertex, vector_count * 2) catch unreachable;

                for (0..vector_count) |i| {
                    copied.@"0".?[i * 2] = slices.@"0".?[idxs[i]];
                    applied.@"0".?[i * 2] = &slices.@"0".?[idxs[i]];
                }
            }

            var shapes_copy = allocator.alloc([]vertex, shape_count) catch unreachable;
            var shapes_ptr_copy = allocator.alloc([]*vertex, shape_count) catch unreachable;

            defer {
                for (shapes_copy, shapes_ptr_copy) |shape, shape_ptr| {
                    allocator.free(shape);
                    allocator.free(shape_ptr);
                }
                allocator.free(shapes_copy);
                allocator.free(shapes_ptr_copy);
            }

            for (vector_count..vector_count + shape_count) |i| {
                shapes_copy[i - vector_count] = allocator.alloc(vertex, slices.@"1".?[idxs[i]].len) catch unreachable;
                shapes_ptr_copy[i - vector_count] = allocator.alloc(*vertex, slices.@"1".?[idxs[i]].len) catch unreachable;

                for (slices.@"1".?[idxs[i]], 0..) |*vector, j| {
                    shapes_copy[i - vector_count][j] = vector.*;
                    shapes_ptr_copy[i - vector_count][j] = vector;
                }
            }

            copied.@"1" = std.mem.concat(allocator, vertex, shapes_copy) catch unreachable;
            applied.@"1" = std.mem.concat(allocator, *vertex, shapes_ptr_copy) catch unreachable;

            // for (vector_count + shape_count..idxs.len) |i| {
            //     copied.@"2".?[i - vector_count - shape_count] = slices.@"2".?[idxs[i]];
            // }

            const buffers = .{
                if (copied.@"0") |vectors| g.VertexBuffer(vertex).init(
                    vectors,
                    g.BufferUsage.DynamicDraw,
                ) else null,
                if (copied.@"1" != null and copied.@"1".?.len > 0) g.VertexBuffer(vertex).init(
                    copied.@"1".?,
                    g.BufferUsage.DynamicDraw,
                ) else null,
                null,
            };

            return .{
                .copied = copied,
                .applied = applied,
                .slices = slices,
                .buffers = buffers,
            };
        }

        pub fn deinit(self: *align(1) const Self, allocator: std.mem.Allocator) void {
            if (self.buffers.@"0") |buffer| buffer.deinit();
            if (self.buffers.@"1") |buffer| buffer.deinit();
            if (self.buffers.@"2") |buffer| buffer.deinit();
            self.freeCopies(allocator);
        }

        pub fn updateBuffers(self: *const Self, data: CopiesTuple) void {
            if (data.@"0") |vecs| {
                self.buffers.@"0".?.bufferData(vecs, g.BufferUsage.DynamicDraw);
            }
            if (data.@"1") |shapes| {
                self.buffers.@"1".?.bufferData(shapes, g.BufferUsage.DynamicDraw);
            }
            if (data.@"2") |camera_pos| {
                self.buffers.@"2".?.bufferData(camera_pos, g.BufferUsage.DynamicDraw);
            }
            _LOGF(std.heap.page_allocator, "{any}", .{data.@"0".?[0].coords});
        }

        pub fn freeCopies(self: *align(1) const Self, allocator: std.mem.Allocator) void {
            if (self.copied.@"0") |vecs| {
                allocator.free(vecs);
                allocator.free(self.applied.@"0".?);
            }
            if (self.copied.@"1") |shapes| {
                allocator.free(shapes);
                allocator.free(self.applied.@"1".?);
            }
            if (self.copied.@"2") |camera_pos| {
                allocator.free(camera_pos);
                allocator.free(self.applied.@"2".?);
            }
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

const std = @import("std");
const g = @import("../root.zig");

fn _LOGF(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void { //TODO: remove
    g.platform.log(std.fmt.allocPrint(allocator, fmt, args) catch unreachable);
}

pub fn AnimationManager(comptime vertex: type) type {
    return struct {
        const Self = @This();
        const DELAY: usize = 30;
        const FRAMES: usize = 25;

        program: g.Program,
        pool: Pool,
        ctx: ?Ctx = null,
        curr_frame: usize = 1,

        pub fn init(
            allocator: std.mem.Allocator,
            program: g.Program,
        ) Self {
            return .{
                .pool = Pool.init(allocator),
                .program = program,
            };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn context(
            self: *Self,
            idxs: []const usize,
            counts: u32,
            slices: SceneSlices,
        ) *Ctx {
            const ptr = self.pool.new();
            ptr.* = Ctx.init(
                self.pool.arena.allocator(),
                idxs,
                counts >> 0x10,
                counts & 0xFFFF,
                slices,
            );
            return ptr;
        }

        pub fn start(
            _: *Self,
            fn_ptr: usize,
            args: []const u8,
        ) void {
            _ = g.Interval.init(@intCast(fn_ptr), args, DELAY, FRAMES);
        }

        ///TODO: maybe make this return the slices accepted by the buffers
        fn translate(ctx: *Ctx, data: VertexData, args: []const f32, count_as_f32: f32) void {
            const pos_x = args[0] / FRAMES * count_as_f32;
            const pos_y = args[1] / FRAMES * count_as_f32;
            const pos_z = args[2] / FRAMES * count_as_f32;
            if (ctx.copied.vectors) |vecs_copy| {
                var i: usize = 0;
                while (i < vecs_copy.len) : (i += 2) {
                    ctx.applied.vectors.?[i].coords[0] = vecs_copy[i].coords[0] + pos_x;
                    ctx.applied.vectors.?[i].coords[1] = vecs_copy[i].coords[1] + pos_y;
                    ctx.applied.vectors.?[i].coords[2] = vecs_copy[i].coords[2] + pos_z;
                    data.vectors.?[i] = ctx.applied.vectors.?[i].*;
                }
            }
        }

        fn rotate(ctx: *Ctx, data: VertexData, args: []const f32, count_as_f32: f32) void {
            _ = data;
            _ = ctx;
            _ = args;
            _ = count_as_f32;
        }

        fn scale(ctx: *Ctx, data: VertexData, args: []const f32, count_as_f32: f32) void {
            _ = data;
            _ = ctx;
            _ = args;
            _ = count_as_f32;
        }

        pub fn animate(self: *Self, geoc: g.Geoc, ctx: *Ctx, args: TrasformArgs) void {
            const allocator = self.pool.arena.allocator();
            // const data = (allocator.dupe(VertexData, &.{ctx.copied}) catch unreachable)[0];
            var data = VertexData.alloc(allocator, .{
                if (ctx.copied.vectors) |vecs| vecs.len else 0,
                if (ctx.copied.shapes) |shapes| shapes.len else 0,
                if (ctx.copied.cameras) |cams| cams.len else 0,
            });
            defer data.free(allocator);

            const count_f32: f32 = @floatFromInt(self.curr_frame);
            switch (args) {
                .Translate => |a| translate(ctx, data, &a, count_f32),
                .Rotate => |a| rotate(ctx, data, &a, count_f32),
                .Scale => |a| scale(ctx, data, &a, count_f32),
            }

            // _LOGF(allocator, "Applied Vector Data : {any}", .{data.vectors.?[0].coords});

            ctx.updateBuffers(data);
            ctx.buffers.draw(geoc, self.program);

            self.curr_frame += 1;

            _LOGF(allocator, "{d}", .{self.pool.arena.queryCapacity()});
        }

        pub fn clear(self: *Self, ctx: *Ctx) void {
            ctx.deinit(self.pool.arena.allocator());
            self.pool.delete(ctx);
            self.ctx = null;
            self.curr_frame = 0;
        }

        const SceneSlices = struct {
            vectors: ?[]vertex = null,
            shapes: ?[][]vertex = null,
            cameras: ?[]struct { vertex } = null,
        };

        const VertexData = struct {
            vectors: ?[]vertex = null,
            shapes: ?[]vertex = null,
            cameras: ?[]vertex = null,

            pub fn alloc(allocator: std.mem.Allocator, tpl: std.meta.Tuple(&.{ usize, usize, usize })) VertexData {
                return .{
                    .vectors = if (tpl[0] > 0) allocator.alloc(vertex, tpl[0]) catch unreachable else null,
                    .shapes = if (tpl[1] > 0) allocator.alloc(vertex, tpl[1]) catch unreachable else null,
                    .cameras = if (tpl[2] > 0) allocator.alloc(vertex, tpl[2]) catch unreachable else null,
                };
            }

            pub fn free(self: *VertexData, allocator: std.mem.Allocator) void {
                if (self.vectors) |vecs| allocator.free(vecs);
                if (self.shapes) |shapes| allocator.free(shapes);
                if (self.cameras) |cams| allocator.free(cams);
                self.vectors = null;
                self.shapes = null;
                self.cameras = null;
            }
        };

        const VertexBuffers = struct {
            vectors: ?g.VertexBuffer(vertex) = null,
            shapes: ?g.VertexBuffer(vertex) = null,
            cameras: ?g.VertexBuffer(vertex) = null,

            pub fn init(data: VertexData) VertexBuffers {
                return .{
                    .vectors = if (data.vectors) |vecs| g.VertexBuffer(vertex).init(vecs, g.BufferUsage.DynamicDraw) else null,
                    .shapes = if (data.shapes) |shapes| g.VertexBuffer(vertex).init(shapes, g.BufferUsage.DynamicDraw) else null,
                    .cameras = if (data.cameras) |cams| g.VertexBuffer(vertex).init(cams, g.BufferUsage.DynamicDraw) else null,
                };
            }

            pub fn deinit(self: *VertexBuffers) void {
                if (self.vectors) |buffer| buffer.deinit();
                if (self.shapes) |buffer| buffer.deinit();
                if (self.cameras) |buffer| buffer.deinit();
                self.vectors = null;
                self.shapes = null;
                self.cameras = null;
            }

            pub fn bufferData(self: VertexBuffers, data: VertexData, usage: g.BufferUsage) void {
                if (self.vectors) |buffer| buffer.bufferData(data.vectors.?, usage);
                if (self.shapes) |buffer| buffer.bufferData(data.shapes.?, usage);
                if (self.cameras) |buffer| buffer.bufferData(data.cameras.?, usage);
            }

            pub fn draw(self: *VertexBuffers, geoc: g.Geoc, program: g.Program) void {
                if (self.vectors) |buffer| geoc.draw(vertex, program, buffer, g.DrawMode.LineLoop);
                if (self.shapes) |buffer| geoc.draw(vertex, program, buffer, g.DrawMode.TriangleFan);
                if (self.cameras) |buffer| geoc.draw(vertex, program, buffer, g.DrawMode.LineLoop);
            }
        };

        const VertexPointers = struct {
            vectors: ?[]*vertex = null,
            shapes: ?[]*vertex = null,
            cameras: ?[]*vertex = null,

            pub fn free(self: *VertexPointers, allocator: std.mem.Allocator) void {
                if (self.vectors) |vecs| allocator.free(vecs);
                if (self.shapes) |shapes| allocator.free(shapes);
                if (self.cameras) |cams| allocator.free(cams);
                self.vectors = null;
                self.shapes = null;
                self.cameras = null;
            }
        };

        pub const Ctx = struct {
            buffers: VertexBuffers,
            copied: VertexData,
            applied: VertexPointers,

            pub fn init(
                allocator: std.mem.Allocator,
                idxs: []const usize,
                vector_count: usize,
                shape_count: usize,
                slices: SceneSlices,
            ) Ctx {
                var copied = VertexData{};
                var applied = VertexPointers{};

                if (vector_count > 0) {
                    copied.vectors = allocator.alloc(vertex, vector_count * 2) catch unreachable;
                    applied.vectors = allocator.alloc(*vertex, vector_count * 2) catch unreachable;

                    for (0..vector_count) |i| {
                        copied.vectors.?[i * 2] = slices.vectors.?[idxs[i] * 2];
                        applied.vectors.?[i * 2] = &slices.vectors.?[idxs[i] * 2];
                        copied.vectors.?[i * 2 + 1] = slices.vectors.?[idxs[i] * 2 + 1];
                        applied.vectors.?[i * 2 + 1] = &slices.vectors.?[idxs[i] * 2 + 1];
                    }
                }

                var shapes_copy = allocator.alloc([]vertex, shape_count) catch unreachable;
                var shapes_ptr_copy = allocator.alloc([]*vertex, shape_count) catch unreachable;
                defer allocator.free(shapes_copy);
                defer allocator.free(shapes_ptr_copy);

                for (vector_count..vector_count + shape_count) |i| {
                    shapes_copy[i - vector_count] = allocator.alloc(vertex, slices.shapes.?[idxs[i]].len) catch unreachable;
                    shapes_ptr_copy[i - vector_count] = allocator.alloc(*vertex, slices.shapes.?[idxs[i]].len) catch unreachable;

                    for (slices.shapes.?[idxs[i]], 0..) |*vector, j| {
                        shapes_copy[i - vector_count][j] = vector.*;
                        shapes_ptr_copy[i - vector_count][j] = vector;
                    }
                }

                if (shapes_copy.len > 0) {
                    //insert padding
                    copied.shapes = std.mem.concat(allocator, vertex, shapes_copy) catch unreachable;
                    applied.shapes = std.mem.concat(allocator, *vertex, shapes_ptr_copy) catch unreachable;
                }

                // TODO: camera implementation
                return .{
                    .copied = copied,
                    .applied = applied,
                    .buffers = VertexBuffers.init(copied),
                };
            }

            pub fn deinit(self: *Ctx, allocator: std.mem.Allocator) void {
                self.copied.free(allocator);
                self.applied.free(allocator);
                self.buffers.deinit();
                self.buffers = VertexBuffers{};
                self.copied = VertexData{};
                self.applied = VertexPointers{};
            }

            pub fn updateBuffers(self: *const Ctx, data: VertexData) void {
                self.buffers.bufferData(data, g.BufferUsage.DynamicDraw);
            }
        };

        const Pool = struct {
            const List = std.SinglyLinkedList(Ctx);

            arena: std.heap.ArenaAllocator,
            free: List,

            pub fn init(
                allocator: std.mem.Allocator,
            ) Pool {
                return .{
                    .arena = std.heap.ArenaAllocator.init(allocator),
                    .free = .{},
                };
            }

            pub fn deinit(
                self: *Pool,
            ) void {
                self.arena.deinit();
            }

            pub fn new(self: *Pool) *Ctx {
                const obj = if (self.free.popFirst()) |node|
                    &node.data
                else
                    self.arena.allocator().create(Ctx) catch unreachable;
                return obj;
            }

            pub fn delete(self: *Pool, obj: *Ctx) void {
                obj.deinit(self.arena.allocator());
                const node: *List.Node = @fieldParentPtr("data", obj);
                self.free.prepend(node);
            }
        };
    };
}

pub const Trasform = enum(u8) {
    Translate,
    Rotate,
    Scale,
};

pub const TrasformArgs = union(enum) {
    Translate: [3]f32,
    Rotate: [3]f32,
    Scale: [3]f32,
};

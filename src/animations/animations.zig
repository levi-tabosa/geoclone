const std = @import("std");
const g = @import("../root.zig");

fn _LOGF(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void { //TODO: remove
    g.platform.log(std.fmt.allocPrint(allocator, fmt, args) catch unreachable);
}

fn Slices(comptime vertex: type) type {
    return struct {
        ?[]vertex,
        ?[][]vertex,
        ?[]struct { vertex },
    };
}

pub fn AnimationManager(comptime vertex: type) type {
    return struct {
        const Self = @This();
        const animation = Animation(vertex);
        const delay = 30;
        const frames = 25;

        program: g.Program,
        pool: Pool(animation),
        ctx: ?Ctx(vertex) = null,
        next: usize = 0,

        pub fn init(
            allocator: std.mem.Allocator,
            program: g.Program,
        ) Self {
            return .{
                .pool = Pool(animation).init(allocator),
                .program = program,
            };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn newContext(
            allocator: std.mem.Allocator,
            idxs: []const u32,
            counts: u32,
            slices: Slices(vertex),
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
            // _: *Self,
            fn_ptr: usize,
            args: []const u8,
        ) void {
            _ = g.Interval.init(@intCast(fn_ptr), args, delay, frames);
        }

        pub fn set(
            self: *Self,
            idxs: []const u32,
            counts: u32,
            args: []const f32,
            fn_ptr: usize,
            vectors_ptr: ?[*]vertex,
            shapes_ptr: ?[*][]vertex,
            cameras_ptr: ?[*]vertex,
        ) void {
            _ = args;
            // const bytes = std.mem.sliceAsBytes(args);
            const vector_count = counts >> 0x10;
            const shape_count = counts & 0xFFFF;

            const selected_vector_ptrs = self.pool.arena.allocator().alloc(*vertex, vector_count) catch unreachable;
            const selected_shape_ptrs = self.pool.arena.allocator().alloc([]*vertex, shape_count) catch unreachable;
            const selected_camera_pos_ptrs = self.pool.arena.allocator().alloc(*vertex, idxs.len - vector_count + shape_count) catch unreachable;

            for (idxs[0..vector_count], 0..) |idx, i| {
                selected_vector_ptrs[i] = &vectors_ptr.?[idx];
                _LOGF(self.pool.arena.allocator(), "{d} {any}", .{ i, vectors_ptr.?[idx] });
            }

            for (idxs[vector_count .. vector_count + shape_count], 0..) |idx, i| {
                for (0..shapes_ptr.?[idx].len) |j| {
                    selected_shape_ptrs[i][j] = &shapes_ptr.?[idx][j];
                }
                _LOGF(self.pool.arena.allocator(), "{d} {any}", .{ i, shapes_ptr.?[idx] });
            }

            for (idxs[vector_count + shape_count .. idxs.len], 0..) |idx, i| {
                selected_camera_pos_ptrs[i] = &cameras_ptr.?[idx];
                _LOGF(self.pool.arena.allocator(), "{d} {any}", .{ i, cameras_ptr.?[idx] });
            }

            // for (selected_vector_ptrs[0]) |value| {
            //     @as(*struct { [3]f32 }, @alignCast(@ptrCast(value)))[0] = .{ 9, 9, 9 };
            // }

            const animations: [3]*animation = .{ self.pool.new(), self.pool.new(), self.pool.new() };

            self.ctx = Ctx(vertex).init(animations, selected_vector_ptrs, selected_shape_ptrs, selected_camera_pos_ptrs, fn_ptr);
        }

        pub fn animate(self: *Self, geoc: g.Geoc) void {
            for (self.ctx.?.animations) |a| {
                a.animate(geoc, self.program);
            }
        }

        pub fn remove(
            self: *Self,
            anim: *animation,
        ) void {
            anim.deinit();
            self.pool.delete(anim);
            self.count -= 1;
        }

        pub fn clear(self: *Self) void {
            while (self.pool.free.popFirst()) |node| {
                node.data.deinit();
                self.pool.delete(&node.data);
            }
            self.count = 0;
        }
    };
}

pub fn Animation(comptime vertex: type) type {
    return struct {
        const Self = @This();

        buffer: g.VertexBuffer(vertex),
        mode: g.DrawMode,

        pub fn init(
            selected: []*vertex,
            mode: g.DrawMode,
        ) Self {
            const vertexes: [selected.len]vertex = undefined;
            for (selected, 0..) |value, i| {
                vertexes[i] = value.*;
            }
            return .{
                .buffer = g.VertexBuffer(vertex).init(selected, g.BufferUsage.DynamicDraw),
                .mode = mode,
            };
        }

        pub fn deinit(
            self: *Self,
        ) void {
            self.buffer.deinit();
        }

        pub fn animate(
            self: *Self,
            geoc_instance: g.Geoc,
            program: g.Program,
        ) void {
            program.use();
            self.buffer.bind();

            inline for (std.meta.fields(vertex)) |field| {
                geoc_instance.platform.vertexAttributePointer(program.platform, vertex, field, false);
            }

            geoc_instance.platform.drawArrays(self.mode, 0, self.buffer.count);
        }
    };
}

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

pub fn Ctx(comptime vertex: type) type {
    return struct {
        const Self = @This();
        const animation = Animation(vertex);

        copied: Slices(vertex),
        slices: Slices(vertex),

        pub fn init(
            allocator: std.mem.Allocator,
            idxs: []const u32,
            vector_count: usize,
            shape_count: usize,
            slices: Slices(vertex),
        ) Self {
            var copied = Slices(vertex){
                allocator.alloc(vertex, vector_count) catch unreachable,
                allocator.alloc([]vertex, shape_count) catch unreachable,
                allocator.alloc(struct { vertex }, idxs.len - vector_count + shape_count) catch unreachable,
            };

            _LOGF(allocator,
                \\idxs {any}
                \\idxs len {d}
                \\vec count {d}
                \\shape count {d}
                \\cam count {d}
                \\slices {}
            , .{
                idxs,
                idxs.len,
                vector_count,
                shape_count,
                idxs.len - vector_count - shape_count,
                slices,
            });

            for (0..vector_count) |i| {
                copied.@"0".?[i] = slices.@"0".?[idxs[i]];
            }

            for (vector_count..vector_count + shape_count) |i| {
                copied.@"1".?[i - vector_count] = allocator.alloc(vertex, slices.@"1".?[idxs[i]].len) catch unreachable;
                for (slices.@"1".?[idxs[i]], 0..) |v, j| {
                    copied.@"1".?[i - vector_count][j] = v;
                }
            }

            _LOGF(allocator, "aaaa", .{});

            for (vector_count + shape_count..idxs.len) |i| {
                copied.@"2".?[i - vector_count - shape_count] = slices.@"2".?[idxs[i]];
            }

            return .{
                .copied = copied,
                .slices = slices,
            };
        }

        ///TODO:change this to accept *Self
        pub fn free(self: *align(1) const Self, allocator: std.mem.Allocator) void {
            _LOGF(allocator, "{}", .{self.*});
            if (self.copied.@"0") |vecs| allocator.free(vecs);
            if (self.copied.@"1") |shapes| {
                for (shapes) |shape| {
                    allocator.free(shape);
                }
            }
            if (self.copied.@"2") |camera_pos| allocator.free(camera_pos);
        }
    };
}

pub const AnimationType = enum(u8) {
    const Self = @This();

    Translate,
    Rotate,
    Scale,

    pub fn getArgsType(self: Self) type {
        return switch (self) {
            .Translate => comptime struct {
                idxs_ptr: [*]const u32,
                idxs_len: usize,
                counts: u32,
                x: f32,
                y: f32,
                z: f32,
            },
            .Rotate => struct {
                idxs_ptr: [*]const u32,
                idxs_len: usize,
                counts: u32,
                x: f32,
                y: f32,
                z: f32,
            },
            .Scale => struct {
                idxs_ptr: [*]const u32,
                idxs_len: usize,
                counts: u32,
                factor: f32,
            },
        };
    }
};

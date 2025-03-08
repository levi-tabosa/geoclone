const std = @import("std");
const g = @import("../root.zig");

pub fn AnimationManager(comptime vertex: type) type {
    return struct {
        const Self = @This();
        const animation = Animation(vertex);

        pool: Pool(animation),
        next: usize = 0,
        delay: u32,
        count: u32,

        pub fn init(
            allocator: std.mem.Allocator,
            delay: u32,
            count: u32,
        ) Self {
            return .{
                .pool = Pool(animation).init(allocator),
                .delay = delay,
                .count = count,
            };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn add(
            self: *Self,
            selected: [][]vertex,
            fn_ptr: i32,
            args: []const u8,
        ) void {
            const anim = self.pool.new();
            anim.* = animation.init(
                self.pool.arena.allocator(),
                selected,
                fn_ptr,
                args,
                self.delay,
                self.count,
            );
            self.count += 1;
        }

        pub fn remove(
            self: *Self,
            anim: *animation,
        ) void {
            animation.deinit(anim);
            self.pool.delete(anim);
            self.count -= 1;
        }

        pub fn animate(self: *Self, geoc_instance: g.Geoc) void {
            while (self.pool.free.popFirst()) |node| {
                animation.animate(node.value, geoc_instance);
            }
        }

        pub fn clear(self: *Self) void {
            while (self.pool.free.popFirst()) |node| {
                animation.deinit(node.value);
                self.pool.delete(node.value);
            }
            self.count = 0;
        }
    };
}

pub fn Animation(comptime vertex: type) type {
    return struct {
        const Self = @This();

        buffer: g.VertexBuffer(vertex),

        pub fn init(
            allocator: std.mem.Allocator,
            selected: [][]vertex,
        ) Self {
            const data = std.mem.concat(allocator, vertex, selected) catch unreachable;

            return .{
                .buffer = g.VertexBuffer(vertex).init(data, g.BufferUsage.DynamicDraw),
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
            mode: g.DrawMode,
        ) void {
            program.use();
            self.buffer.bind();

            inline for (std.meta.fields(vertex)) |field| {
                geoc_instance.platform.vertexAttributePointer(program.platform, vertex, field, false);
            }

            self.platform.drawArrays(mode, 0, self.buffer.count);
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

const Args = union(AnimationType) {
    Translate: struct {
        x: f32,
        y: f32,
        z: f32,
    },
    Rotate: struct {
        x: f32,
        y: f32,
        z: f32,
    },
    Scale: struct {
        factor: f32,
    },
};

pub const AnimationType = enum(u8) {
    Translate,
    Rotate,
    Scale,
};

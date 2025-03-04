const std = @import("std");
const g = @import("geoc");
const canvas = @import("../geometry/canvas.zig");
const V3 = canvas.V3;

const Animation = struct {
    const Self = @This();

    next_frame: u32 = 0,
    trasform: fn (original: []V3, dest: []V3, count: u32, frames: u32) []V3,
    buffer: g.VertexBuffer(V3),

    pub fn init(
        scene: canvas.Scene,
        fn_ptr: i32,
        args: []const u8,
        delay: u32,
        count: u32, //TODO: maybe remove
        interval_handle: i32,
    ) Self {
        const selected = 
        return Animation{
            .buffer = g.VertexBuffer(V3).init(selected, g.VertexUsage.DynamicDraw),
            .interval_handle = g.Interval.init(fn_ptr, args: []const u8, delay: u32, count: u32)
        };
    }

    pub fn animate(self: Self, scene: *canvas.Scene, indexes: []const u32, copy: []const V3, count: u32, frames: u32) void {
        const data = scene.allocator.alloc(V3, indexes.len) catch unreachable;
        defer scene.allocator.free(indexes);

        for (copy, 0..) |value, i| {
            data[i] = self.trasform(value, count, frames);
        }

        self.buffer.bufferSubData(indexes, data);
        self.next_frame += 1;
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }
};

const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

fn rotateVector(coords: *const [3]f32, angle_x: f32, angle_z: f32) Vector {
    return .{ .coords = coords, .changed = rotZX(coords.*, angle_x, angle_z) };
}

fn rotZX(u: [3]f32, angle_x: f32, angle_z: f32) [3]f32 {
    return .{
        u[0] * @cos(angle_z) + u[1] * @sin(angle_z),
        (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @cos(angle_x) + u[2] * @sin(angle_x),
        u[2] * @cos(angle_x) - (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @sin(angle_x),
    };
}

pub const Vector = struct {
    coords: *const [3]f32,
    changed: [3]f32, //TODO bad name
};

pub const Demo = struct {
    const allocator = std.heap.page_allocator;
    const Self = @This();
    const grid_res = 10;

    allocator: Allocator,
    zoom: f32,
    angle_x: f32,
    angle_z: f32,
    axis: [6]Vector,
    grid: [grid_res << 2]Vector,
    vectors: ArrayList(Vector),
    shapes: ArrayList(ArrayList(Vector)),

    pub fn init() Self {
        const angle_x: f32 = 0.7;
        const angle_z: f32 = 0.7;
        const _i = 0.3;

        const j = grid_res >> 1;
        const upperLimit = if (grid_res & 1 == 1) j + 1 else j;
        const fixed: f32 = j * _i;
        var i: i32 = -j;

        var grid: [grid_res << 2]Vector = undefined;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i)) * _i;
            const index = @as(usize, @intCast(i + j << 2));
            grid[index] = rotateVector(&.{ idx, fixed, 0.0 }, angle_x, angle_z);
            grid[(index) + 1] = rotateVector(&.{ idx, -fixed, 0.0 }, angle_x, angle_z);
            grid[(index) + 2] = rotateVector(&.{ fixed, idx, 0.0 }, angle_x, angle_z);
            grid[(index) + 3] = rotateVector(&.{ -fixed, idx, 0.0 }, angle_x, angle_z);
        }

        const axis = [_]Vector{
            rotateVector(&.{ fixed, 0.0, 0.0 }, angle_x, angle_z),
            rotateVector(&.{ -fixed, 0.0, 0.0 }, angle_x, angle_z),
            rotateVector(&.{ 0.0, fixed, 0.0 }, angle_x, angle_z),
            rotateVector(&.{ 0.0, -fixed, 0.0 }, angle_x, angle_z),
            rotateVector(&.{ 0.0, 0.0, fixed }, angle_x, angle_z),
            rotateVector(&.{ 0.0, 0.0, -fixed }, angle_x, angle_z),
        };

        return .{
            .axis = axis,
            .grid = grid,
            .angle_x = angle_x,
            .angle_z = angle_z,
            .zoom = _i,
            .allocator = allocator,
            .vectors = ArrayList(Vector).init(allocator),
            .shapes = ArrayList(ArrayList(Vector)).init(allocator),
        };
    }

    pub fn updateLines(self: *Self) void {
        const j = grid_res >> 1;
        const upperLimit = if (grid_res & 1 == 1) j + 1 else j;
        const fixed: f32 = j * self.zoom;
        var i: i32 = -j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i)) * self.zoom;
            const index = @as(usize, @intCast(i + j << 2));
            self.grid[index] = rotateVector(&.{ idx, fixed, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 1] = rotateVector(&.{ idx, -fixed, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 2] = rotateVector(&.{ fixed, idx, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 3] = rotateVector(&.{ -fixed, idx, 0.0 }, self.angle_x, self.angle_z);
        }
        self.axis = [_]Vector{
            rotateVector(&.{ fixed, 0.0, 0.0 }, self.angle_x, self.angle_z),
            rotateVector(&.{ -fixed, 0.0, 0.0 }, self.angle_x, self.angle_z),
            rotateVector(&.{ 0.0, fixed, 0.0 }, self.angle_x, self.angle_z),
            rotateVector(&.{ 0.0, -fixed, 0.0 }, self.angle_x, self.angle_z),
            rotateVector(&.{ 0.0, 0.0, fixed }, self.angle_x, self.angle_z),
            rotateVector(&.{ 0.0, 0.0, -fixed }, self.angle_x, self.angle_z),
        };
        for (self.vectors.items) |*vec| {
            vec.changed = rotZX(vec.coords.*, self.angle_x, self.angle_z);
        }
    }

    pub fn setAngleX(self: *Self, angle: f32) void {
        self.angle_x = angle;
    }

    pub fn setAngleZ(self: *Self, angle: f32) void {
        self.angle_z = angle;
    }

    pub fn setZoom(self: *Self, zoom: f32) void {
        self.zoom += zoom;
    }

    pub fn addVector(self: *Self, x: f32, y: f32, z: f32) void {
        const vector = rotateVector(&.{ x, y, z }, self.angle_x, self.angle_z);
        self.vectors.append(vector) catch @panic("Failed to add vector");
    }

    pub fn clearVectors(self: *Self) void {
        self.vectors.deinit();
        self.vectors = ArrayList(Vector).init(self.allocator);
    }
};
pub const State = struct {
    ptr: *anyopaque,
    setAnglesFn: *const fn (ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void,
    setZoomFn: *const fn (ptr: *anyopaque, zoom: f32) callconv(.C) void,
    setInsertFn: *const fn (ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void,
};

const std = @import("std");
const geoc = @import("../root.zig");

const Allocator = std.mem.Allocator;

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _LOGF(allocator: std.mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

fn rV3(u: *V3, angle_x: f32, angle_z: f32) void {
    u.changed[0] = u.coords[0] * @cos(angle_z) + u.coords[1] * @sin(angle_z);
    u.changed[1] = (u.coords[1] * @cos(angle_z) - u.coords[0] * @sin(angle_z)) * @cos(angle_x) + u.coords[2] * @sin(angle_x);
    u.changed[2] = u.coords[2] * @cos(angle_x) - (u.coords[1] * @cos(angle_z) - u.coords[0] * @sin(angle_z)) * @sin(angle_x);
}

fn rotateV3(coords: *const [3]f32, angle_x: f32, angle_z: f32) V3 {
    return .{ .coords = coords.*, .changed = rotZX(coords.*, angle_x, angle_z) };
}

fn rotZX(u: [3]f32, angle_x: f32, angle_z: f32) [3]f32 {
    return .{
        u[0] * @cos(angle_z) + u[1] * @sin(angle_z),
        (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @cos(angle_x) + u[2] * @sin(angle_x),
        u[2] * @cos(angle_x) - (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @sin(angle_x),
    };
}

pub const V3 = struct {
    coords: [3]f32,
    changed: [3]f32 = .{ 0, 0, 0 },
};

pub const Scene = struct {
    const Self = @This();
    const res = 11;

    allocator: Allocator,
    zoom: f32,
    angle_x: f32,
    angle_z: f32,
    axis: [6]V3,
    grid: [res * 4]V3,
    vectors: ?[]V3 = null,
    shapes: ?[][]V3 = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        const angle_x: f32 = 0.7;
        const angle_z: f32 = 0.7;
        const zoom = 0.3;

        const j = res / 2;
        const upperLimit = if (res & 1 == 1) j + 1 else j;
        const fixed: f32 = j * zoom;

        var grid: [res * 4]V3 = undefined;
        var i: i32 = -j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i)) * zoom;
            const index = @as(usize, @intCast((i + j) * 4));
            grid[index] = rotateV3(&.{ idx, fixed, 0.0 }, angle_x, angle_z);
            grid[index + 1] = rotateV3(&.{ idx, -fixed, 0.0 }, angle_x, angle_z);
            grid[index + 2] = rotateV3(&.{ fixed, idx, 0.0 }, angle_x, angle_z);
            grid[index + 3] = rotateV3(&.{ -fixed, idx, 0.0 }, angle_x, angle_z);
        }

        const axis = [_]V3{
            rotateV3(&.{ fixed, 0.0, 0.0 }, angle_x, angle_z),
            rotateV3(&.{ -fixed, 0.0, 0.0 }, angle_x, angle_z),
            rotateV3(&.{ 0.0, fixed, 0.0 }, angle_x, angle_z),
            rotateV3(&.{ 0.0, -fixed, 0.0 }, angle_x, angle_z),
            rotateV3(&.{ 0.0, 0.0, fixed }, angle_x, angle_z),
            rotateV3(&.{ 0.0, 0.0, -fixed }, angle_x, angle_z),
        };

        return .{
            .allocator = allocator,
            .zoom = zoom,
            .angle_x = angle_x,
            .angle_z = angle_z,
            .axis = axis,
            .grid = grid,
        };
    }

    pub fn updateLines(self: *Self) void {
        const j = res / 2;
        const upperLimit = if (res & 1 == 1) j + 1 else j;
        const fixed: f32 = j * self.zoom;
        var i: i32 = -j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i)) * self.zoom;
            const index = @as(usize, @intCast((i + j) * 4));
            self.grid[index] = rotateV3(&.{ idx, fixed, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 1] = rotateV3(&.{ idx, -fixed, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 2] = rotateV3(&.{ fixed, idx, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 3] = rotateV3(&.{ -fixed, idx, 0.0 }, self.angle_x, self.angle_z);
        }
        self.axis = [_]V3{
            rotateV3(&.{ fixed, 0.0, 0.0 }, self.angle_x, self.angle_z),
            rotateV3(&.{ -fixed, 0.0, 0.0 }, self.angle_x, self.angle_z),
            rotateV3(&.{ 0.0, fixed, 0.0 }, self.angle_x, self.angle_z),
            rotateV3(&.{ 0.0, -fixed, 0.0 }, self.angle_x, self.angle_z),
            rotateV3(&.{ 0.0, 0.0, fixed }, self.angle_x, self.angle_z),
            rotateV3(&.{ 0.0, 0.0, -fixed }, self.angle_x, self.angle_z),
        };
        if (self.vectors) |vectors| {
            for (vectors) |*vec| {
                vec.* = rotateV3(&vec.coords, self.angle_x, self.angle_z);
            }
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
        const len = if (self.vectors) |vecs| vecs.len else 0;

        const origin = V3{ .coords = .{ 0.0, 0.0, 0.0 }, .changed = .{ 0.0, 0.0, 0.0 } };
        const new_vector = rotateV3(&.{ x * self.zoom, y * self.zoom, z * self.zoom }, self.angle_x, self.angle_z);

        var new_vector_array = self.allocator.alloc(V3, len + 2) catch @panic("OOM");

        for (0..len) |i| {
            new_vector_array[i] = self.vectors.?[i];
        }

        new_vector_array[len] = origin;
        new_vector_array[len + 1] = new_vector;
        self.vectors = new_vector_array;
    }

    pub fn clearVectors(self: *Self) void {
        if (self.vectors) |vectors| {
            self.allocator.free(vectors);
            self.vectors = null;
        }
    }
};
pub const State = struct {
    ptr: *anyopaque,
    angles_fn_ptr: *const fn (ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void,
    zoom_fn_ptr: *const fn (ptr: *anyopaque, zoom: f32) callconv(.C) void,
    insert_fn_ptr: *const fn (ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void,
    clear_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
};

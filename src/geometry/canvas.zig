const std = @import("std");
const geoc = @import("../root.zig");

const Allocator = std.mem.Allocator;

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _LOGF(allocator: std.mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

fn rV3(u: *_V3, angle_x: f32, angle_z: f32, zoom: f32) void {
    u.changed[0] = zoom * (u.coords[0] * @cos(angle_z) + u.coords[1] * @sin(angle_z));
    u.changed[1] = zoom * ((u.coords[1] * @cos(angle_z) - u.coords[0] * @sin(angle_z)) * @cos(angle_x) + u.coords[2] * @sin(angle_x));
    u.changed[2] = zoom * (u.coords[2] * @cos(angle_x) - (u.coords[1] * @cos(angle_z) - u.coords[0] * @sin(angle_z)) * @sin(angle_x));
}

fn _V3(coords: *const [3]f32, angle_x: f32, angle_z: f32, zoom: f32) _V3 {
    return .{ .coords = coords.*, .changed = rotZX(coords.*, angle_x, angle_z, zoom) };
}

fn rotZX(u: [3]f32, angle_x: f32, angle_z: f32, zoom: f32) [3]f32 {
    return .{
        zoom * (u[0] * @cos(angle_z) + u[1] * @sin(angle_z)),
        zoom * ((u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @cos(angle_x) + u[2] * @sin(angle_x)),
        zoom * (u[2] * @cos(angle_x) - (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @sin(angle_x)),
    };
}

pub const V3 = struct {
    coords: [3]f32,
    changed: [3]f32 = .{ 0, 0, 0 },
};

pub const Scene = struct {
    const Self = @This();
    const res = 21;

    allocator: Allocator,
    zoom: f32,
    angle_x: f32,
    angle_z: f32,
    axis: [6]_V3,
    grid: [res * 4]_V3,
    vectors: ?[]_V3 = null,
    shapes: ?[][]_V3 = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        const j = res / 2;
        const upperLimit = if (res & 1 == 1) j + 1 else j;
        var i: i32 = -j;
        var grid: [res * 4]_V3 = undefined;
        const fixed: f32 = j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            grid[index] = _V3(&.{ idx, fixed, 0.0 }, 0.0, 0.0, 0.3);
            grid[index + 1] = _V3(&.{ idx, -fixed, 0.0 }, 0.0, 0.0, 0.3);
            grid[index + 2] = _V3(&.{ fixed, idx, 0.0 }, 0.0, 0.0, 0.3);
            grid[index + 3] = _V3(&.{ -fixed, idx, 0.0 }, 0.0, 0.0, 0.3);
        }

        const axis = [_]_V3{
            _V3(&.{ fixed, 0.0, 0.0 }, 0.0, 0.0, 0.3),
            _V3(&.{ -fixed, 0.0, 0.0 }, 0.0, 0.0, 0.3),
            _V3(&.{ 0.0, fixed, 0.0 }, 0.0, 0.0, 0.3),
            _V3(&.{ 0.0, -fixed, 0.0 }, 0.0, 0.0, 0.3),
            _V3(&.{ 0.0, 0.0, fixed }, 0.0, 0.0, 0.3),
            _V3(&.{ 0.0, 0.0, -fixed }, 0.0, 0.0, 0.3),
        };

        return .{
            .allocator = allocator,
            .zoom = 0.3,
            .angle_x = 0.7,
            .angle_z = 0.7,
            .axis = axis,
            .grid = grid,
        };
    }

    pub fn updateLines(self: *Self) void {
        for (&self.grid) |*vec| {
            rV3(vec, self.angle_x, self.angle_z, self.zoom);
        }

        for (&self.axis) |*vec| {
            rV3(vec, self.angle_x, self.angle_z, self.zoom);
        }

        if (self.vectors) |vectors| {
            for (vectors) |*vec| {
                rV3(vec, self.angle_x, self.angle_z, self.zoom);
            }
        }

        if (self.shapes) |shapes| {
            for (shapes) |shape| {
                for (shape) |*vec| {
                    rV3(vec, self.angle_x, self.angle_z, self.zoom);
                }
            }
        }
    }

    pub fn addVector(self: *Self, x: f32, y: f32, z: f32) void {
        const len = if (self.vectors) |vectors| vectors.len else 0;

        var new_vector_array = self.allocator.alloc(_V3, len + 2) catch @panic("OOM");

        for (0..len) |i| {
            new_vector_array[i] = self.vectors.?[i];
        }
        new_vector_array[len] = _V3{ .coords = .{ 0.0, 0.0, 0.0 }, .changed = .{ 0.0, 0.0, 0.0 } };
        new_vector_array[len + 1] = _V3(&.{ x, y, z }, self.angle_x, self.angle_z, self.zoom);

        if (self.vectors) |vec| {
            self.allocator.free(vec);
        }

        self.vectors = new_vector_array;
        self.updateLines();
    }

    pub fn clear(self: *Self) void {
        if (self.vectors) |vectors| {
            self.allocator.free(vectors);
            self.vectors = null;
        }
        if (self.shapes) |shapes| {
            self.allocator.free(shapes);
            self.shapes = null;
        }
    }

    pub fn insertCube(self: *Self) void {
        self.insertShape(Shape.CUBE);
    }

    pub fn insertPyramid(self: *Self) void {
        self.insertShape(Shape.PYRAMID);
    }

    fn insertShape(self: *Self, shape: Shape) void {
        const len = if (self.shapes) |shapes| shapes.len else 0;

        var new_shape = self.allocator.alloc([]_V3, len + 1) catch @panic("OOM");

        for (0..len) |i| {
            new_shape[i] = self.shapes.?[i];
        }

        new_shape[len] = @constCast(shape.getVectors(null));

        self.shapes = new_shape;
        self.updateLines();
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
};

pub const Shape = enum {
    CUBE,
    PYRAMID,
    // SPHERE,

    pub fn getVectors(self: Shape, res: ?usize) []const _V3 { //TODO: res used on sphere
        _ = res;
        return switch (self) {
            .CUBE => &[_]_V3{
                _V3{ .coords = .{ -1, 1, 1 } },   _V3{ .coords = .{ -1, 1, -1 } },
                _V3{ .coords = .{ 1, 1, -1 } },   _V3{ .coords = .{ 1, 1, 1 } },
                _V3{ .coords = .{ 1, -1, 1 } },   _V3{ .coords = .{ 1, -1, -1 } },
                _V3{ .coords = .{ -1, -1, -1 } }, _V3{ .coords = .{ -1, -1, 1 } },
            },
            .PYRAMID => &[_]_V3{
                _V3{ .coords = .{ 0, 0, 1 } },    _V3{ .coords = .{ -1, 1, -1 } },
                _V3{ .coords = .{ 1, 1, -1 } },   _V3{ .coords = .{ 1, -1, -1 } },
                _V3{ .coords = .{ -1, -1, -1 } },
            },
        };
    }
};

pub const State = struct {
    ptr: *anyopaque,
    angles_fn_ptr: *const fn (ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void,
    zoom_fn_ptr: *const fn (ptr: *anyopaque, zoom: f32) callconv(.C) void,
    insert_fn_ptr: *const fn (ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void,
    clear_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
    cube_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
    pyramid_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
};

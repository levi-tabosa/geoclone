const std = @import("std");

pub const Vector = struct {
    coords: [3]f32,
    changed: [3]f32, //TODO bad name
};

fn rVector(coords: [3]f32, angle_x: f32, angle_z: f32) Vector {
    return .{ .coords = coords, .changed = rotZX(coords, angle_x, angle_z) };
}

fn rotZX(u: [3]f32, angle_x: f32, angle_z: f32) [3]f32 {
    return .{
        u[0] * @cos(angle_z) + u[1] * @sin(angle_z),
        (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @cos(angle_x) + u[2] * @sin(angle_x),
        u[2] * @cos(angle_x) - (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @sin(angle_x),
    };
}

pub const Demo = struct {
    const Self = @This();
    const grid_res = 10;

    zoom: f32,
    angle_x: f32,
    angle_z: f32,
    axis: [6]Vector,
    grid: [grid_res << 2]Vector,
    vectors: ?*[]Vector = null,
    shapes: ?*[][]Vector = null,

    pub fn init() Self {
        const a_x: f32 = 0.7;
        const a_z: f32 = 0.7;
        const _i = 0.3;

        const j = grid_res >> 1;
        const upperLimit = if (grid_res & 1 == 1) j + 1 else j;
        const fixed: f32 = j * _i;
        var i: i32 = -j;

        var grid: [grid_res << 2]Vector = undefined;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i)) * _i;
            const index = @as(usize, @intCast(i + j << 2));
            grid[index] = rVector(.{ idx, fixed, 0.0 }, a_x, a_z);
            grid[(index) + 1] = rVector(.{ idx, -fixed, 0.0 }, a_x, a_z);
            grid[(index) + 2] = rVector(.{ fixed, idx, 0.0 }, a_x, a_z);
            grid[(index) + 3] = rVector(.{ -fixed, idx, 0.0 }, a_x, a_z);
        }

        const axis = [_]Vector{
            rVector(.{ fixed, 0.0, 0.0 }, a_x, a_z),
            rVector(.{ -fixed, 0.0, 0.0 }, a_x, a_z),
            rVector(.{ 0.0, fixed, 0.0 }, a_x, a_z),
            rVector(.{ 0.0, -fixed, 0.0 }, a_x, a_z),
            rVector(.{ 0.0, 0.0, fixed }, a_x, a_z),
            rVector(.{ 0.0, 0.0, -fixed }, a_x, a_z),
        };

        return .{
            .axis = axis,
            .grid = grid,
            .angle_x = a_x,
            .angle_z = a_z,
            .zoom = _i,
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
            self.grid[index] = rVector(.{ idx, fixed, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 1] = rVector(.{ idx, -fixed, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 2] = rVector(.{ fixed, idx, 0.0 }, self.angle_x, self.angle_z);
            self.grid[(index) + 3] = rVector(.{ -fixed, idx, 0.0 }, self.angle_x, self.angle_z);
        }
        self.axis = [_]Vector{
            rVector(.{ fixed, 0.0, 0.0 }, self.angle_x, self.angle_z),
            rVector(.{ -fixed, 0.0, 0.0 }, self.angle_x, self.angle_z),
            rVector(.{ 0.0, fixed, 0.0 }, self.angle_x, self.angle_z),
            rVector(.{ 0.0, -fixed, 0.0 }, self.angle_x, self.angle_z),
            rVector(.{ 0.0, 0.0, fixed }, self.angle_x, self.angle_z),
            rVector(.{ 0.0, 0.0, -fixed }, self.angle_x, self.angle_z),
        };
    }

    pub fn setX(self: *Self, angle: f32) void {
        self.angle_x = angle;
    }

    pub fn setZ(self: *Self, angle: f32) void {
        self.angle_z = angle;
    }

    pub fn setZoom(self: *Self, zoom: f32) void {
        self.zoom += zoom;
    }
};
pub const State = struct {
    ptr: *anyopaque,
    setAnglesFn: *const fn (ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void,
    setZoomFn: *const fn (ptr: *anyopaque, zoom: f32) callconv(.C) void,
};

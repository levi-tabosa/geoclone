const std = @import("std");
const geoc = @import("../root.zig"); //TODO: erase

const Allocator = std.mem.Allocator;

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _LOGF(allocator: Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

fn rotXZ(u: [3]f32, angle_x: f32, angle_y: f32, zoom: f32) [3]f32 {
    return .{
        zoom * (u[2] * @sin(angle_y) + u[0] * @cos(angle_y)),
        zoom * (u[1] * @cos(angle_x)) - (u[2] * @sin(angle_y)),
        zoom * (u[1] * @sin(angle_x)) + (u[2] * @cos(angle_x)) * @cos(angle_y) - (u[2] * @sin(angle_y) + u[0] * @cos(angle_y)) * @sin(angle_x),
    };
}

fn rXYZ(u: [3]f32, angle_x: f32, angle_y: f32, angle_z: f32, zoom: f32) [3]f32 {
    var x = u[0];
    var y = u[1];
    var z = u[2];

    // Z
    const tmp_x = x * @cos(angle_z) - y * @sin(angle_z);
    var tmp_y = x * @sin(angle_z) + y * @cos(angle_z);
    x = tmp_x;
    y = tmp_y;

    // Y
    const tmp_z = z * @cos(angle_y) - x * @sin(angle_y);
    x = z * @sin(angle_y) + x * @cos(angle_y);
    z = tmp_z;

    // X
    tmp_y = y * @cos(angle_x) - z * @sin(angle_x);
    z = y * @sin(angle_x) + z * @cos(angle_x);
    y = tmp_y;

    return .{
        zoom * x,
        zoom * y,
        zoom * z,
    };
}

fn rotXYZ(
    u: *V3,
    angle_x: f32,
    angle_y: f32,
    angle_z: f32,
) void {
    var x = u.coords[0];
    var y = u.coords[1];
    var z = u.coords[2];

    //Z
    const tmp_x = x * @cos(angle_z) - y * @sin(angle_z);
    var tmp_y = x * @sin(angle_z) + y * @cos(angle_z);
    x = tmp_x;
    y = tmp_y;

    //Y
    const tmp_z = z * @cos(angle_y) - x * @sin(angle_y);
    x = z * @sin(angle_y) + x * @cos(angle_y);
    z = tmp_z;

    //X
    tmp_y = y * @cos(angle_x) - z * @sin(angle_x);
    z = y * @sin(angle_x) + z * @cos(angle_x);
    y = tmp_y;

    u.coords[0] = x;
    u.coords[1] = y;
    u.coords[2] = z;
}

pub const V3 = struct {
    coords: [3]f32,

    pub fn new(x: f32, y: f32, z: f32) V3 {
        return .{ .coords = .{ x, y, z } };
    }

    pub fn add(a: V3, b: V3) V3 {
        return .{ .coords = .{
            a.coords[0] + b.coords[0],
            a.coords[1] + b.coords[1],
            a.coords[2] + b.coords[2],
        } };
    }

    pub fn subtract(a: V3, b: V3) V3 {
        return .{ .coords = .{
            a.coords[0] - b.coords[0],
            a.coords[1] - b.coords[1],
            a.coords[2] - b.coords[2],
        } };
    }

    pub fn dot(a: V3, b: V3) f32 {
        return a.coords[0] * b.coords[0] + a.coords[1] * b.coords[1] + a.coords[2] * b.coords[2];
    }

    pub fn cross(a: V3, b: V3) V3 {
        return .{ .coords = .{
            a.coords[1] * b.coords[2] - a.coords[2] * b.coords[1],
            a.coords[2] * b.coords[0] - a.coords[0] * b.coords[2],
            a.coords[0] * b.coords[1] - a.coords[1] * b.coords[0],
        } };
    }

    pub fn normalize(v: V3) V3 {
        const length = std.math.sqrt(
            v.coords[0] * v.coords[0] + v.coords[1] * v.coords[1] + v.coords[2] * v.coords[2],
        );
        return .{ .coords = .{
            v.coords[0] / length,
            v.coords[1] / length,
            v.coords[2] / length,
        } };
    }
};

pub const Camera = struct {
    const Self = @This();

    position: V3,
    target: V3 = V3{ .coords = .{ 0.0, 0.0, 0.0 } },
    up: V3 = V3{ .coords = .{ 0.0, 1.0, 0.0 } },
    radius: ?f32 = null,

    pub fn init(position: V3, radius: ?f32) Self {
        return .{
            .position = position,
            .radius = radius,
        };
    }

    pub fn createViewMatrix(self: Self) [16]f32 {
        const z_axis = V3.normalize(V3.subtract(self.position, self.target));
        const x_axis = V3.normalize(V3.cross(self.up, z_axis));
        const y_axis = V3.cross(z_axis, x_axis);

        return .{
            x_axis.coords[0],
            y_axis.coords[0],
            z_axis.coords[0],
            0.0,
            x_axis.coords[1],
            y_axis.coords[1],
            z_axis.coords[1],
            0.0,
            x_axis.coords[2],
            y_axis.coords[2],
            z_axis.coords[2],
            0.0,
            -V3.dot(x_axis, self.position),
            -V3.dot(y_axis, self.position),
            -V3.dot(z_axis, self.position),
            1.0,
        };
    }
};

pub const Scene = struct {
    const Self = @This();
    const resolution = 10;

    allocator: Allocator,
    zoom: f32,
    pitch: f32,
    yaw: f32,
    axis: [6]V3,
    grid: []V3,
    vectors: ?[]V3 = null,
    shapes: ?[][]V3 = null,
    camera: Camera,
    cameras: ?[]Camera = null,
    view_matrix: [16]f32,

    pub fn init(allocator: Allocator) Self {
        const pitch = 0.7;
        const yaw = 0.7;
        const j = resolution / 2;
        const upperLimit = if (resolution & 1 == 1) j + 1 else j;
        var i: i32 = -j;
        var grid = allocator.alloc(V3, resolution * 4) catch @panic("OOM");
        const fixed: f32 = j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            grid[index] = V3.new(idx, 0.0, fixed);
            grid[index + 1] = V3.new(idx, 0.0, -fixed);
            grid[index + 2] = V3.new(fixed, 0.0, idx);
            grid[index + 3] = V3.new(-fixed, 0.0, idx);
        }

        const axis = [_]V3{
            V3.new(fixed, 0.0, 0.0),
            V3.new(-fixed, 0.0, 0.0),
            V3.new(0.0, fixed, 0.0),
            V3.new(0.0, -fixed, 0.0),
            V3.new(0.0, 0.0, fixed),
            V3.new(0.0, 0.0, -fixed),
        };
        const radius = 10.0;
        const camera = Camera.init(
            .{ .coords = .{
                radius * @cos(yaw) * @cos(pitch),
                radius * @sin(pitch),
                radius * @sin(yaw) * @cos(pitch),
            } },
            radius,
        );

        // const camera = Camera.init(.{ .coords = .{ 0, 1, 0 } }, null);

        return .{
            .allocator = allocator,
            .zoom = 1.0, //TODO: fix zoom
            .pitch = pitch,
            .yaw = yaw,
            .axis = axis,
            .grid = grid,
            .camera = camera,
            .view_matrix = camera.createViewMatrix(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.grid);

        if (self.cameras) |cameras| {
            self.allocator.free(cameras);
        }

        if (self.shapes) |shapes| {
            for (shapes) |shape| {
                self.allocator.free(shape);
            }
            self.allocator.free(shapes);
        }
    }

    pub fn updateViewMatrix(self: *Self) void {
        if (self.camera.radius) |r| {
            self.camera.position = .{
                .coords = .{
                    r * @cos(self.yaw) * @cos(self.pitch) * self.zoom,
                    r * @sin(self.pitch) * self.zoom,
                    r * @sin(self.yaw) * @cos(self.pitch) * self.zoom,
                },
            };
        } else {
            self.camera.target = V3.add(self.camera.position, V3{ .coords = .{
                @cos(self.yaw) * @cos(self.pitch),
                @sin(self.pitch),
                @sin(self.yaw) * @cos(self.pitch),
            } });
        }

        self.view_matrix = self.camera.createViewMatrix();
    }

    // pub fn updateLines(self: *Self) void {
    //     for (self.grid) |*vec| {
    //         rV3(vec, self.pitch, self.yaw, self.zoom);
    //     }

    //     for (&self.axis) |*vec| {
    //         rV3(vec, self.pitch, self.yaw, self.zoom);
    //     }

    //     if (self.vectors) |vectors| {
    //         for (vectors) |*vec| {
    //             rV3(vec, self.pitch, self.yaw, self.zoom);
    //         }
    //     }

    //     if (self.shapes) |shapes| {
    //         for (shapes) |shape| {
    //             for (shape) |*vec| {
    //                 rV3(vec, self.pitch, self.yaw, self.zoom);
    //             }
    //         }
    //     }
    // }

    pub fn insertVector(self: *Self, x: f32, y: f32, z: f32) void {
        const len = if (self.vectors) |vectors| vectors.len else 0;

        var new_vector_array = self.allocator.alloc(V3, len + 2) catch @panic("OOM");

        for (0..len) |i| {
            new_vector_array[i] = self.vectors.?[i];
        }
        new_vector_array[len] = V3.new(x, y, z);
        new_vector_array[len + 1] = V3.new(0.0, 0.0, 0.0);

        if (self.vectors) |vec| {
            self.allocator.free(vec);
        }

        self.vectors = new_vector_array;
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

    pub fn rotate(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, x: f32, y: f32, z: f32) void {
        for (0..idxs_len) |i| {
            const idx = idxs_ptr[i] * 2;
            rotXYZ(&self.vectors.?[idx], x, y, z);
        }
    }

    pub fn scale(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, factor: f32) void {
        for (0..idxs_len) |i| {
            const idx = idxs_ptr[i] * 2;

            for (&self.vectors.?[idx].coords) |*value| {
                value.* *= factor;
            }
        }
    }

    pub fn translate(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, dx: f32, dy: f32, dz: f32) void {
        for (0..idxs_len) |i| {
            const idx = idxs_ptr[i] * 2;

            self.vectors.?[idx].coords[0] += dx;
            self.vectors.?[idx].coords[1] += dy;
            self.vectors.?[idx].coords[2] += dz;
        }
    }

    pub fn insertCube(self: *Self) void {
        self.insertShape(Shape.CUBE);
    }

    pub fn insertPyramid(self: *Self) void {
        self.insertShape(Shape.PYRAMID);
    }

    pub fn insertSphere(self: *Self) void {
        self.insertShape(Shape.SPHERE);
    }

    pub fn insertCone(self: *Self) void {
        self.insertShape(Shape.CONE);
    }

    fn insertShape(self: *Self, shape: Shape) void {
        const len = if (self.shapes) |shapes| shapes.len else 0;

        if (len > 0) self.allocator.free(self.shapes.?);
        var new_shapes = self.allocator.alloc([]V3, len + 1) catch @panic("OOM");

        for (0..len) |i| {
            new_shapes[i] = self.shapes.?[i];
        }

        new_shapes[len] = @constCast(shape.getVectors(null)); //TODO: REMOVE THIS CAST

        self.shapes = new_shapes;
    }

    pub fn setZoom(self: *Scene, zoom_delta: f32) void {
        self.zoom += zoom_delta; //TODO: MAYBE INCREMENT INSTEAD ??
        self.updateViewMatrix();
    }

    pub fn setPitch(self: *Self, angle: f32) void {
        self.pitch = angle;
    }

    pub fn setYaw(self: *Self, angle: f32) void {
        self.yaw = angle;
    }

    pub fn setResolution(self: *Self, res: usize) void {
        self.allocator.free(self.grid);

        const j: i32 = @intCast(res / 2);
        const upperLimit = if (res & 1 == 1) j + 1 else j;
        var i: i32 = -j;
        self.grid = self.allocator.alloc(V3, res * 4) catch @panic("OOM");
        const fixed: f32 = @floatFromInt(j);

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            self.grid[index] = V3.new(idx, 0.0, fixed);
            self.grid[index + 1] = V3.new(idx, 0.0, -fixed);
            self.grid[index + 2] = V3.new(fixed, 0.0, idx);
            self.grid[index + 3] = V3.new(-fixed, 0.0, idx);
        }

        self.axis = [_]V3{
            V3.new(fixed, 0.0, 0.0),
            V3.new(-fixed, 0.0, 0.0),
            V3.new(0.0, fixed, 0.0),
            V3.new(0.0, -fixed, 0.0),
            V3.new(0.0, 0.0, fixed),
            V3.new(0.0, 0.0, -fixed),
        };
    }
};

pub const Shape = enum {
    CUBE,
    PYRAMID,
    SPHERE,
    CONE,

    pub fn getVectors(self: Shape, res: ?usize) []const V3 {
        const resolution = res orelse 32;
        return switch (self) {
            .CUBE => &[_]V3{
                .{ .coords = .{ -1, 1, 1 } },   .{ .coords = .{ -1, 1, -1 } },
                .{ .coords = .{ 1, 1, -1 } },   .{ .coords = .{ 1, 1, 1 } },
                .{ .coords = .{ 1, -1, 1 } },   .{ .coords = .{ 1, -1, -1 } },
                .{ .coords = .{ -1, -1, -1 } }, .{ .coords = .{ -1, -1, 1 } },
            },
            .PYRAMID => &[_]V3{
                .{ .coords = .{ 0, 0, 1 } },    .{ .coords = .{ -1, 1, -1 } },
                .{ .coords = .{ 1, 1, -1 } },   .{ .coords = .{ 1, -1, -1 } },
                .{ .coords = .{ -1, -1, -1 } },
            },
            .SPHERE => Sphere.generate(resolution),
            .CONE => Cone.generate(resolution),
        };
    }
};

pub const Sphere = struct {
    pub fn generate(res: usize) []const V3 {
        const stacks = res;
        const slices = res;
        const radius: f32 = 1.0;
        // TODO: use state allocator
        const vertexes = std.heap.page_allocator.alloc(V3, res * res) catch @panic("OOM");

        for (0..stacks) |i| {
            const theta = @as(f32, @floatFromInt(i)) * std.math.pi / @as(f32, @floatFromInt(stacks - 1));
            const y = @cos(theta) * radius;
            const ring_radius = @sin(theta) * radius;

            for (0..slices) |j| {
                const phi = @as(f32, @floatFromInt(j)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(slices));
                const x = ring_radius * @cos(phi);
                const z = ring_radius * @sin(phi);

                vertexes[i * j + j] = .{ .coords = .{ x, y, z } };
            }
        }
        return vertexes;
    }
};

pub const Cone = struct {
    pub fn generate(res: usize) []const V3 {
        const pi = std.math.pi;

        const slices = res;
        const radius: f32 = 1.0;
        const height: f32 = 2.0;
        const vertexes = std.heap.page_allocator.alloc(V3, slices + 1) catch @panic("OOM");

        vertexes[0] = .{ .coords = .{ 0, 0, height } };

        for (1..slices) |i| {
            const theta = @as(f32, @floatFromInt(i)) * 2.0 * pi / @as(f32, @floatFromInt(slices)); // Ângulo do segmento
            const x = @cos(theta) * radius;
            const z = @sin(theta) * radius;

            vertexes[i] = .{ .coords = .{ x, z, 0 } };
        }
        return vertexes;
    }
};

// pub const CameraMode = enum(u32) {
//     Orbit = 0,
//     Free = 1,
// };

pub const State = struct {
    ptr: *anyopaque,
    set_angles_fn_ptr: *const fn (*anyopaque, f32, f32) callconv(.C) void,
    get_pitch_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
    get_yaw_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
    zoom_fn_ptr: *const fn (*anyopaque, f32) callconv(.C) void,
    insert_fn_ptr: *const fn (*anyopaque, f32, f32, f32) callconv(.C) void,
    clear_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    set_res_fn_ptr: *const fn (*anyopaque, usize) callconv(.C) void,
    cube_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    pyramid_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    sphere_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    cone_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    rotate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, f32, f32, f32) callconv(.C) void,
    scale_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, f32) callconv(.C) void,
    translate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, f32, f32, f32) callconv(.C) void,
};

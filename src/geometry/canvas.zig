const std = @import("std");
const geoc = @import("../root.zig"); //TODO: erase

const Allocator = std.mem.Allocator;

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _LOGF(allocator: Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

fn rV3(u: *V3, p_angle: f32, y_angle: f32, zoom: f32) void { // rotates a V3 based on yaw, pitch and zoom
    u.changed[0] = zoom * (u.coords[0] * @cos(y_angle) + u.coords[1] * @sin(y_angle));
    u.changed[1] = zoom * ((u.coords[1] * @cos(y_angle) - u.coords[0] * @sin(y_angle)) * @cos(p_angle) + u.coords[2] * @sin(p_angle));
    u.changed[2] = zoom * (u.coords[2] * @cos(p_angle) - (u.coords[1] * @cos(y_angle) - u.coords[0] * @sin(y_angle)) * @sin(p_angle));
}

fn vec3(coords: *const [3]f32, angle_x: f32, angle_z: f32, zoom: f32) V3 {
    return .{ .coords = coords.*, .changed = rotXZ(coords.*, angle_x, angle_z, zoom) };
}

fn rotXZ(u: [3]f32, angle_x: f32, angle_z: f32, zoom: f32) [3]f32 {
    return .{
        zoom * (u[0] * @cos(angle_z) + u[1] * @sin(angle_z)),
        zoom * ((u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @cos(angle_x) + u[2] * @sin(angle_x)),
        zoom * (u[2] * @cos(angle_x) - (u[1] * @cos(angle_z) - u[0] * @sin(angle_z)) * @sin(angle_x)),
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
    changed: [3]f32 = .{ 0, 0, 0 },
};

pub const Scene = struct {
    const Self = @This();
    const res = 31;

    allocator: Allocator,
    zoom: f32,
    pitch: f32,
    yaw: f32,
    axis: [6]V3,
    grid: []V3,
    vectors: ?[]V3 = null,
    shapes: ?[][]V3 = null,

    pub fn init(allocator: Allocator) Self {
        const j = res / 2;
        const upperLimit = if (res & 1 == 1) j + 1 else j;
        var i: i32 = -j;
        var grid = allocator.alloc(V3, res * 4) catch @panic("OOM");
        const fixed: f32 = j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            grid[index] = vec3(&.{ idx, fixed, 0.0 }, 0.0, 0.0, 0.3);
            grid[index + 1] = vec3(&.{ idx, -fixed, 0.0 }, 0.0, 0.0, 0.3);
            grid[index + 2] = vec3(&.{ fixed, idx, 0.0 }, 0.0, 0.0, 0.3);
            grid[index + 3] = vec3(&.{ -fixed, idx, 0.0 }, 0.0, 0.0, 0.3);
        }

        const axis = [_]V3{
            vec3(&.{ fixed, 0.0, 0.0 }, 0.0, 0.0, 0.3),
            vec3(&.{ -fixed, 0.0, 0.0 }, 0.0, 0.0, 0.3),
            vec3(&.{ 0.0, fixed, 0.0 }, 0.0, 0.0, 0.3),
            vec3(&.{ 0.0, -fixed, 0.0 }, 0.0, 0.0, 0.3),
            vec3(&.{ 0.0, 0.0, fixed }, 0.0, 0.0, 0.3),
            vec3(&.{ 0.0, 0.0, -fixed }, 0.0, 0.0, 0.3),
        };

        return .{
            .allocator = allocator,
            .zoom = 0.3,
            .pitch = 0.7,
            .yaw = 0.7,
            .axis = axis,
            .grid = grid,
        };
    }

    pub fn updateLines(self: *Self) void {
        for (self.grid) |*vec| {
            rV3(vec, self.pitch, self.yaw, self.zoom);
        }

        for (&self.axis) |*vec| {
            rV3(vec, self.pitch, self.yaw, self.zoom);
        }

        if (self.vectors) |vectors| {
            for (vectors) |*vec| {
                rV3(vec, self.pitch, self.yaw, self.zoom);
            }
        }

        if (self.shapes) |shapes| {
            for (shapes) |shape| {
                for (shape) |*vec| {
                    rV3(vec, self.pitch, self.yaw, self.zoom);
                }
            }
        }
    }

    pub fn addVector(self: *Self, x: f32, y: f32, z: f32) void {
        const len = if (self.vectors) |vectors| vectors.len else 0;

        var new_vector_array = self.allocator.alloc(V3, len + 2) catch @panic("OOM");

        for (0..len) |i| {
            new_vector_array[i] = self.vectors.?[i];
        }
        new_vector_array[len] = vec3(&.{ x, y, z }, self.pitch, self.yaw, self.zoom);
        new_vector_array[len + 1] = .{ .coords = .{ 0.0, 0.0, 0.0 }, .changed = .{ 0.0, 0.0, 0.0 } };

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

    pub fn rotate(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, x: f32, y: f32, z: f32) void {
        for (0..idxs_len) |i| {
            const idx = idxs_ptr[i] * 2;

            rotXYZ(&self.vectors.?[idx], x, y, z);
        }
        self.updateLines();
    }

    pub fn scale(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, factor: f32) void {
        for (0..idxs_len) |i| {
            const idx = idxs_ptr[i] * 2;

            for (&self.vectors.?[idx].coords) |*value| {
                value.* *= factor;
            }
        }
        self.updateLines();
    }

    pub fn translate(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, dx: f32, dy: f32, dz: f32) void {
        for (0..idxs_len) |i| {
            const idx = idxs_ptr[i] * 2;

            self.vectors.?[idx].coords[0] += dx;
            self.vectors.?[idx].coords[1] += dy;
            self.vectors.?[idx].coords[2] += dz;
        }
        self.updateLines();
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

        var new_shape = self.allocator.alloc([]V3, len + 1) catch @panic("OOM");

        for (0..len) |i| {
            new_shape[i] = self.shapes.?[i];
        }

        new_shape[len] = @constCast(shape.getVectors(null)); //TODO: get rid of this cast

        self.shapes = new_shape;
        self.updateLines();
    }

    pub fn setZoom(self: *Self, zoom: f32) void {
        self.zoom += zoom;
    }

    pub fn setPitch(self: *Self, angle: f32) void {
        self.pitch = angle;
    }

    pub fn setYaw(self: *Self, angle: f32) void {
        self.yaw = angle;
    }

    pub fn setResolution(self: *Self, resolution: usize) void {
        _log("a");

        const j: i32 = @intCast(resolution / 2);
        var i: i32 = -j;
        const fixed: f32 = @floatFromInt(j);
        self.grid = self.allocator.alloc(V3, resolution * 4) catch @panic("OOM");
        const upperLimit = if (resolution & 1 == 1) j + 1 else j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            self.grid[index] = vec3(&.{ idx, fixed, 0.0 }, 0.0, 0.0, 0.3);
            self.grid[index + 1] = vec3(&.{ idx, -fixed, 0.0 }, 0.0, 0.0, 0.3);
            self.grid[index + 2] = vec3(&.{ fixed, idx, 0.0 }, 0.0, 0.0, 0.3);
            self.grid[index + 3] = vec3(&.{ -fixed, idx, 0.0 }, 0.0, 0.0, 0.3);
        }
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
    /// Gera os vértices da esfera com a resolução especificada.
    pub fn generate(res: usize) []const V3 {
        const pi = std.math.pi;
        const stacks = res; // Número de divisões verticais (latitude)
        const slices = res; // Número de divisões horizontais (longitude)
        const radius: f32 = 1.0;
        const vertexes = std.heap.page_allocator.alloc(V3, res * res) catch @panic("OOM"); // Placeholder para os vértices gerados dinamicamente

        // Iterar pelas divisões (latitude e longitude)
        for (0..stacks) |i| {
            const theta = @as(f32, @floatFromInt(i)) * pi / @as(f32, @floatFromInt(stacks - 1)); // Ângulo da latitude
            const y = @cos(theta) * radius; // Altura na esfera
            const ring_radius = @sin(theta) * radius; // Raio do anel

            for (0..slices) |j| {
                const phi = @as(f32, @floatFromInt(j)) * 2.0 * pi / @as(f32, @floatFromInt(slices)); // Ângulo da longitude
                const x = ring_radius * @cos(phi);
                const z = ring_radius * @sin(phi);

                vertexes[i * j + j] = .{ .coords = .{ x, y, z } }; // Adiciona o vértice
            }
        }

        return vertexes;
    }
};

pub const Cone = struct {
    /// Gera os vértices do cone com a resolução especificada.
    pub fn generate(res: usize) []const V3 {
        const pi = std.math.pi;

        const slices = res; // Número de segmentos da base
        const radius: f32 = 1.0;
        const height: f32 = 2.0;
        const vertexes = std.heap.page_allocator.alloc(V3, slices + 1) catch @panic("OOM");

        // Vértice do topo do cone
        vertexes[0] = .{ .coords = .{ 0, 0, height } };

        // Vértices da base
        for (1..slices) |i| {
            const theta = @as(f32, @floatFromInt(i)) * 2.0 * pi / @as(f32, @floatFromInt(slices)); // Ângulo do segmento
            const x = @cos(theta) * radius;
            const z = @sin(theta) * radius;

            vertexes[i] = .{ .coords = .{ x, z, 0 } };
        }

        return vertexes;
    }
};

pub const State = struct {
    ptr: *anyopaque,
    set_angles_fn_ptr: *const fn (*anyopaque, f32, f32) callconv(.C) void,
    get_pitch_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
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

const std = @import("std");
const geoc = @import("../root.zig"); //TODO: erase

const Allocator = std.mem.Allocator;

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _LOGF(allocator: Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch unreachable);
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
    camera: *Camera,
    cameras: ?[]Camera = null,
    view_matrix: [16]f32,

    pub fn init(allocator: Allocator) Self {
        const pitch = 0.7;
        const yaw = 0.7;
        const j = resolution / 2;
        const upperLimit = j;
        var i: i32 = -j;
        var grid = allocator.alloc(V3, resolution * 4) catch unreachable;
        const fixed: f32 = j;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            grid[index] = V3.init(idx, fixed, 0.0);
            grid[index + 1] = V3.init(idx, -fixed, 0.0);
            grid[index + 2] = V3.init(fixed, idx, 0.0);
            grid[index + 3] = V3.init(-fixed, idx, 0.0);
        }

        const axis = [_]V3{
            V3.init(fixed, 0.0, 0.0),
            V3.init(-fixed, 0.0, 0.0),
            V3.init(0.0, fixed, 0.0),
            V3.init(0.0, -fixed, 0.0),
            V3.init(0.0, 0.0, fixed),
            V3.init(0.0, 0.0, -fixed),
        };

        const radius = 10.0;
        const camera = allocator.create(Camera) catch unreachable;
        camera.* = Camera.init(
            allocator,
            .{
                .coords = .{
                    radius * @cos(yaw) * @cos(pitch),
                    radius * @sin(yaw) * @cos(pitch),
                    radius * @sin(pitch),
                },
            },
            radius,
        );

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

        if (self.vectors) |vectors| {
            self.allocator.free(vectors);
        }

        if (self.shapes) |shapes| {
            for (shapes) |shape| {
                self.allocator.free(shape);
            }
            self.allocator.free(shapes);
        }

        if (self.cameras) |cameras| {
            for (cameras) |camera| {
                self.allocator.free(camera.shape);
            }
            self.allocator.free(cameras);
        }
    }

    pub fn updateViewMatrix(self: *Self) void {
        if (self.camera.radius) |r| {
            self.camera.pos = .{
                .coords = .{
                    r * @cos(self.yaw) * @cos(self.pitch),
                    r * @sin(self.yaw) * @cos(self.pitch),
                    r * @sin(self.pitch),
                },
            };
        } else {
            self.camera.target = V3.add(self.camera.pos, V3{ .coords = .{
                @cos(-self.yaw) * @cos(self.pitch),
                @sin(-self.yaw) * @cos(self.pitch),
                @sin(self.pitch),
            } });
        }

        self.view_matrix = self.camera.createViewMatrix();
    }

    pub fn setPitch(self: *Self, angle: f32) void {
        self.pitch = angle;
    }

    pub fn setYaw(self: *Self, angle: f32) void {
        self.yaw = angle;
    }

    pub fn setZoom(self: *Scene, zoom_delta: f32) void {
        self.zoom += zoom_delta;
        self.updateViewMatrix();
    }

    pub fn insertVector(self: *Self, x: f32, y: f32, z: f32) void {
        const len = if (self.vectors) |vectors| vectors.len else 0;

        var new_vector_array = self.allocator.alloc(V3, len + 2) catch unreachable;

        for (0..len) |i| {
            new_vector_array[i] = self.vectors.?[i];
        }
        new_vector_array[len] = V3.init(x, y, z);
        new_vector_array[len + 1] = V3.init(0.0, 0.0, 0.0);

        if (len > 0) {
            self.allocator.free(self.vectors.?);
        }

        self.vectors = new_vector_array;
    }

    pub fn insertCamera(self: *Self, pos_x: f32, pos_y: f32, pos_z: f32) void {
        _LOGF(
            self.allocator,
            "Size of Scene: {} \nAlign of Scene:{}",
            .{
                @sizeOf(Scene),
                @alignOf(Scene),
            },
        );
        inline for (std.meta.fields(Self)) |field| {
            _LOGF(
                self.allocator,
                "Offset of {s}:\t{}\nAlignment :\t{}\nType :\t{any}\nValue in scene:\t{any}",
                .{
                    field.name,
                    @offsetOf(Self, field.name),
                    field.alignment,
                    field.type,
                    @field(self, field.name),
                },
            );
        }
        const len = if (self.cameras) |cameras| cameras.len else 0;

        var new_cameras_array = self.allocator.alloc(Camera, len + 1) catch unreachable;

        for (0..len) |i| {
            new_cameras_array[i] = self.cameras.?[i];
        }
        new_cameras_array[len] = Camera.init(self.allocator, V3.init(pos_x, pos_y, pos_z), null);

        if (len > 0) {
            self.allocator.free(self.cameras.?);
        }

        self.cameras = new_cameras_array;
    }

    fn insertShape(self: *Self, shape: Shape) void {
        const len = if (self.shapes) |shapes| shapes.len else 0;

        var new_shapes = self.allocator.alloc([]V3, len + 1) catch unreachable;

        for (0..len) |i| {
            new_shapes[i] = self.shapes.?[i];
        }
        new_shapes[len] = shape.getVectors(self.allocator, null);

        if (len > 0) self.allocator.free(self.shapes.?);

        self.shapes = new_shapes;
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

    pub fn clear(self: *Self) void {
        if (self.vectors) |vectors| {
            self.allocator.free(vectors);
            self.vectors = null;
        }
        if (self.shapes) |shapes| {
            self.allocator.free(shapes);
            self.shapes = null;
        }
        if (self.cameras) |cameras| {
            for (cameras) |camera| {
                self.allocator.free(camera.shape);
            }
            self.allocator.free(cameras);
            self.cameras = null;
        }
        _LOGF(self.allocator, "{}", .{geoc.gpa.detectLeaks()});
    }

    pub fn setResolution(self: *Self, res: usize) void {
        self.allocator.free(self.grid);

        const j: i32 = @intCast(res / 2);
        const fixed: f32 = @floatFromInt(j);
        const upperLimit = j;
        var i: i32 = -j;
        self.grid = self.allocator.alloc(V3, res * 4) catch unreachable;

        while (i < upperLimit) : (i += 1) {
            const idx: f32 = @as(f32, @floatFromInt(i));
            const index = @as(usize, @intCast((i + j) * 4));
            self.grid[index] = V3.init(idx, fixed, 0.0);
            self.grid[index + 1] = V3.init(idx, -fixed, 0.0);
            self.grid[index + 2] = V3.init(fixed, idx, 0.0);
            self.grid[index + 3] = V3.init(-fixed, idx, 0.0);
        }

        self.axis = [_]V3{
            V3.init(fixed, 0.0, 0.0),
            V3.init(-fixed, 0.0, 0.0),
            V3.init(0.0, fixed, 0.0),
            V3.init(0.0, -fixed, 0.0),
            V3.init(0.0, 0.0, fixed),
            V3.init(0.0, 0.0, -fixed),
        };
    }

    pub fn setCamera(self: *Self, index: usize) void {
        if (self.cameras) |cameras| {
            if (index < cameras.len) {
                if (self.camera.radius != null) {
                    self.allocator.destroy(self.camera);
                }
                self.camera = &cameras[index];
            } else {
                const r = 10;

                self.camera = self.allocator.create(Camera) catch unreachable;
                self.camera.* = Camera.init(
                    self.allocator,
                    .{ .coords = .{ r, r, r } },
                    r,
                );
            }
        }
    }

    pub fn scale(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, factor: f32) void { // maybe assert
        const l = shorts >> 16;
        const r = shorts & 65535;

        for (idxs_ptr[0..l]) |idx| {
            for (&self.vectors.?[idx * 2].coords) |*value| {
                value.* *= factor;
            }
        }

        for (idxs_ptr[l .. l + r]) |idx| {
            for (self.shapes.?[idx]) |*vertex| {
                for (&vertex.coords) |*value| {
                    value.* *= factor;
                }
            }
        }

        for (idxs_ptr[l + r .. idxs_len]) |idx| {
            for (&self.cameras.?[idx].pos.coords) |*value| {
                value.* *= factor;
            }
        }
    }

    pub fn rotate(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, x: f32, y: f32, z: f32) void {
        const l = shorts >> 16;
        const r = shorts & 65535;

        for (idxs_ptr[0..l]) |idx| {
            rotXYZ(&self.vectors.?[idx * 2], x, y, z);
        }

        for (idxs_ptr[l .. l + r]) |idx| {
            for (self.shapes.?[idx]) |*vertex| {
                rotXYZ(vertex, x, y, z);
            }
        }

        for (idxs_ptr[l + r .. idxs_len]) |idx| {
            rotXYZ(&self.cameras.?[idx].pos, x, y, z);
        }
    }

    pub fn translate(self: *Self, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, dx: f32, dy: f32, dz: f32) void {
        const l = shorts >> 16;
        const r = shorts & 65535;

        for (idxs_ptr[0..l]) |idx| {
            self.vectors.?[idx * 2].coords[0] += dx;
            self.vectors.?[idx * 2].coords[1] += dy;
            self.vectors.?[idx * 2].coords[2] += dz;
        }

        for (idxs_ptr[l .. l + r]) |idx| {
            for (self.shapes.?[idx]) |*vertex| {
                vertex.coords[0] += dx;
                vertex.coords[1] += dy;
                vertex.coords[2] += dz;
            }
        }

        for (idxs_ptr[l + r .. idxs_len]) |idx| {
            self.cameras.?[idx].pos.coords[0] += dx;
            self.cameras.?[idx].pos.coords[1] += dy;
            self.cameras.?[idx].pos.coords[2] += dz;
            for (self.cameras.?[idx].shape) |*vertex| {
                vertex.coords[0] += dx;
                vertex.coords[1] += dy;
                vertex.coords[2] += dz;
            }
        }
    }

    pub fn reflect(self: *Scene, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, coord_idx: u8, factor: f32) void {
        const l = shorts >> 16;
        const r = shorts & 65535;

        for (idxs_ptr[0..l]) |idx| {
            self.vectors.?[idx * 2].coords[coord_idx] *= factor;
        }

        for (idxs_ptr[l .. l + r]) |idx| {
            for (self.shapes.?[idx]) |*vertex| {
                vertex.coords[coord_idx] *= factor;
            }
        }

        for (idxs_ptr[l + r .. idxs_len]) |idx| {
            self.cameras.?[idx].pos.coords[coord_idx] *= factor;
        }
    }
};

pub const Camera = struct {
    const Self = @This();

    pos: V3,
    target: V3 = .{ .coords = .{ 0.0, 0.0, 0.0 } },
    up: V3 = .{ .coords = .{ 0.0, 0.0, 1.0 } },
    radius: ?f32 = null,
    shape: []V3,

    pub fn init(allocator: Allocator, position: V3, radius: ?f32) Self {
        const shape = allocator.alloc(V3, 8) catch unreachable;
        shape[0] = .{ .coords = .{ -0.05, -0.05, -0.05 } };
        shape[1] = .{ .coords = .{ -0.05, -0.05, 0.05 } };
        shape[2] = .{ .coords = .{ 0.05, -0.05, 0.05 } };
        shape[3] = .{ .coords = .{ 0.05, -0.05, -0.05 } };
        shape[4] = .{ .coords = .{ -0.05, 0.05, -0.05 } };
        shape[5] = .{ .coords = .{ -0.05, 0.05, 0.05 } };
        shape[6] = .{ .coords = .{ 0.05, 0.05, 0.05 } };
        shape[7] = .{ .coords = .{ 0.05, 0.05, -0.05 } };
        return .{
            .pos = position,
            .radius = radius,
            .shape = shape,
        };
    }

    pub fn deinit(allocator: Allocator, self: Self) void {
        allocator.free(self.shape);
    }

    pub fn createViewMatrix(self: Self) [16]f32 {
        const z_axis = V3.normalize(V3.subtract(self.pos, self.target));
        const x_axis = V3.normalize(V3.cross(self.up, z_axis));
        const y_axis = V3.cross(z_axis, x_axis);

        return .{
            x_axis.coords[0],          y_axis.coords[0],          z_axis.coords[0],          0.0,
            x_axis.coords[1],          y_axis.coords[1],          z_axis.coords[1],          0.0,
            x_axis.coords[2],          y_axis.coords[2],          z_axis.coords[2],          0.0,
            -V3.dot(x_axis, self.pos), -V3.dot(y_axis, self.pos), -V3.dot(z_axis, self.pos), 1.0,
        };
    }
};

pub const Shape = enum {
    CUBE,
    PYRAMID,
    SPHERE,
    CONE,
    // CAMERA, //TODO: maybe change

    pub fn getVectors(self: Shape, allocator: Allocator, res: ?usize) []V3 {
        const resolution = res orelse 16;
        return switch (self) {
            .CUBE => {
                const vectors = allocator.alloc(V3, 8) catch unreachable;
                vectors[0] = .{ .coords = .{ -1, -1, -1 } };
                vectors[1] = .{ .coords = .{ -1, -1, 1 } };
                vectors[2] = .{ .coords = .{ 1, -1, 1 } };
                vectors[3] = .{ .coords = .{ 1, -1, -1 } };
                vectors[4] = .{ .coords = .{ -1, 1, -1 } };
                vectors[5] = .{ .coords = .{ -1, 1, 1 } };
                vectors[6] = .{ .coords = .{ 1, 1, 1 } };
                vectors[7] = .{ .coords = .{ 1, 1, -1 } };
                return vectors;
            },
            .PYRAMID => {
                const vectors = allocator.alloc(V3, 5) catch unreachable;
                vectors[0] = .{ .coords = .{ 0, 0, 1 } };
                vectors[1] = .{ .coords = .{ -1, -1, -1 } };
                vectors[2] = .{ .coords = .{ 1, -1, -1 } };
                vectors[3] = .{ .coords = .{ 1, 1, -1 } };
                vectors[4] = .{ .coords = .{ -1, 1, -1 } };
                return vectors;
            },
            .SPHERE => Sphere.generate(allocator, resolution),
            .CONE => Cone.generate(allocator, resolution),
        };
    }
};

pub const Sphere = struct {
    pub fn generate(allocator: Allocator, res: usize) []V3 {
        const stacks = res;
        const slices = res;
        const radius: f32 = 1.0;

        const vertexes = allocator.alloc(V3, (stacks + 1) * slices) catch unreachable;

        var index: usize = 0;
        for (0..stacks) |i| {
            const theta = @as(f32, @floatFromInt(i)) * std.math.pi / @as(f32, @floatFromInt(stacks));
            const z = @cos(theta) * radius;
            const ring_radius = @sin(theta) * radius;

            for (0..slices) |j| {
                const phi = @as(f32, @floatFromInt(j)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(slices));
                const x = ring_radius * @cos(phi);
                const y = ring_radius * @sin(phi);

                vertexes[index] = .{ .coords = .{ x, y, z } };
                index += 1;
            }
        }
        return vertexes;
    }
};

pub const Cone = struct {
    pub fn generate(allocator: Allocator, res: usize) []V3 {
        const slices = res;
        const radius: f32 = 1.0;
        const height: f32 = 2.0;

        const vertexes = allocator.alloc(V3, slices + 2) catch unreachable;

        var index: usize = 0;
        vertexes[index] = .{ .coords = .{ 0, 0, height } };
        index += 1;

        for (0..slices) |i| {
            const theta = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(slices));
            const x = @cos(theta) * radius;
            const y = @sin(theta) * radius;

            vertexes[index] = .{ .coords = .{ x, y, 0 } };
            index += 1;
        }

        vertexes[index] = .{ .coords = .{ 0, 0, 0 } };
        return vertexes;
    }
};

pub const V3 = struct {
    coords: [3]f32,

    pub fn init(x: f32, y: f32, z: f32) V3 {
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

const std = @import("std");
const Allocator = std.mem.Allocator;
// const geoc = @import("../root.zig"); //TODO: erase

// fn _log(txt: []const u8) void { //TODO: erase
//     geoc.platform.log(txt);
// }

// pub fn _LOGF(allocator: Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
//     _log(std.fmt.allocPrint(allocator, txt, args) catch unreachable);
// }

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
    const resolution = 20;

    allocator: Allocator,
    zoom: f32,
    pitch: f32,
    yaw: f32,
    axis: [6]V3,
    grid: []V3,
    vectors: std.ArrayList(V3),
    shapes: std.ArrayList([]V3),
    camera: *Camera,
    cameras: std.ArrayList(Camera),
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
            .view_matrix = camera.viewMatrix(),
            .vectors = std.ArrayList(V3).init(allocator),
            .shapes = std.ArrayList([]V3).init(allocator),
            .cameras = std.ArrayList(Camera).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.grid);

        self.vectors.deinit();

        for (self.shapes.items) |shape| {
            self.allocator.free(shape);
        }
        self.shapes.deinit();

        self.cameras.deinit();
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

        self.view_matrix = self.camera.viewMatrix();
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
        self.vectors.append(V3.init(x, y, z)) catch unreachable;
        self.vectors.append(V3.init(0.0, 0.0, 0.0)) catch unreachable;
    }

    pub fn insertShape(self: *Self, new_shape: Shape) []V3 {
        self.shapes.append(new_shape.create(self.allocator, null)) catch unreachable;
        return self.shapes.getLast();
    }

    pub fn insertCamera(self: *Self, pos_x: f32, pos_y: f32, pos_z: f32) void {
        self.cameras.append(Camera.init(V3.init(pos_x, pos_y, pos_z), null)) catch unreachable;
    }

    /// TODO:fix crash when calling this while a fps cam is active
    pub fn clear(self: *Self) void {
        self.vectors.clearAndFree();
        for (self.shapes.items) |shape| {
            self.allocator.free(shape);
        }
        self.shapes.clearAndFree();
        self.cameras.clearAndFree();
    }

    pub fn setResolution(self: *Self, res: usize) void {
        const j: i32 = @intCast(res / 2);
        const fixed: f32 = @floatFromInt(j);
        const upperLimit = j;
        var i: i32 = -j;

        self.allocator.free(self.grid);
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

    ///TODO: change the passing -1 from js interpreted as usize::MAX hack to a proper solution
    pub fn setCamera(self: *Self, index: usize) void {
        if (self.cameras.getLastOrNull() != null and index != std.math.maxInt(usize)) {
            if (self.camera.radius) |_| {
                //TODO: maybe reuse the camera object instead of reconstructing
                self.allocator.destroy(self.camera);
            }
            self.camera = &self.cameras.items[index];
        } else {
            const r = 10;

            self.camera = self.allocator.create(Camera) catch unreachable;

            self.camera.* = Camera.init(
                .{ .coords = .{ r, r, r } },
                r,
            );
        }
    }

    pub fn scale(self: *Self, idxs_ptr: [*]const usize, idxs_len: usize, counts: u32, factor: f32) void {
        const vectors_count = counts >> 0x10;
        const shapes_count = counts & 0xFFFF;

        for (idxs_ptr[0..vectors_count]) |idx| {
            for (&self.vectors.items[idx * 2].coords) |*value| {
                value.* *= factor;
            }
        }

        for (idxs_ptr[vectors_count .. vectors_count + shapes_count]) |idx| {
            for (self.shapes.items[idx]) |*vertex| {
                for (&vertex.coords) |*value| {
                    value.* *= factor;
                }
            }
        }

        for (idxs_ptr[vectors_count + shapes_count .. idxs_len]) |idx| {
            for (&self.cameras.items[idx].pos.coords) |*value| {
                value.* *= factor;
            }
        }
    }

    pub fn rotate(self: *Self, idxs_ptr: [*]const usize, idxs_len: usize, counts: u32, x: f32, y: f32, z: f32) void {
        const vectors_count = counts >> 0x10;
        const shapes_count = counts & 0xFFFF;

        for (idxs_ptr[0..vectors_count]) |idx| {
            rotXYZ(&self.vectors.items[idx * 2], x, y, z);
        }

        for (idxs_ptr[vectors_count .. vectors_count + shapes_count]) |idx| {
            for (self.shapes.items[idx]) |*vertex| {
                rotXYZ(vertex, x, y, z);
            }
        }

        for (idxs_ptr[vectors_count + shapes_count .. idxs_len]) |idx| {
            rotXYZ(&self.cameras.items[idx].pos, x, y, z);
        }
    }

    ///TODO: pass in coords_flags instead of coord_idx as a single u8
    pub fn reflect(self: *Scene, idxs_ptr: [*]const usize, idxs_len: usize, counts: u32, coord_flags: u8) void {
        const vectors_count = counts >> 0x10;
        const shapes_count = counts & 0xFFFF;

        if (coord_flags & 1 == 1) {
            self.reflectCoord(idxs_ptr, idxs_len, vectors_count, shapes_count, 0);
        }

        if (coord_flags & 2 == 2) {
            self.reflectCoord(idxs_ptr, idxs_len, vectors_count, shapes_count, 1);
        }

        if (coord_flags & 4 == 4) {
            self.reflectCoord(idxs_ptr, idxs_len, vectors_count, shapes_count, 2);
        }
    }

    fn reflectCoord(
        self: *Scene,
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        vectors_count: usize,
        shapes_count: usize,
        coord_idx: u8,
    ) void {
        const factor: f32 = 1.0 / 25.0;

        for (idxs_ptr[0..vectors_count]) |idx| {
            self.vectors.items[idx * 2].coords[coord_idx] *= factor;
        }

        for (idxs_ptr[vectors_count .. vectors_count + shapes_count]) |idx| {
            for (self.shapes.items[idx]) |*vertex| {
                vertex.coords[coord_idx] *= factor;
            }
        }

        for (idxs_ptr[vectors_count + shapes_count .. idxs_len]) |idx| {
            self.cameras.items[idx].pos.coords[coord_idx] *= factor;
            for (&self.cameras.items[idx].shape) |*vertex| {
                vertex.coords[coord_idx] *= factor;
            }
        }
    }
};

pub const Camera = struct {
    const Self = @This();

    pos: V3,
    target: V3 = .{ .coords = .{ 0.0, 0.0, 0.0 } },
    up: V3 = .{ .coords = .{ 0.0, 0.0, 1.0 } },
    radius: ?f32 = null,
    shape: [8]V3,

    pub fn init(pos: V3, radius: ?f32) Self {
        const half_edge_len = 0.05; // lines will appear if  near is set smaller than 0.1
        const cube: [8]V3 = .{
            .{ .coords = .{ pos.coords[0] - half_edge_len, pos.coords[1] - half_edge_len, pos.coords[2] - half_edge_len } },
            .{ .coords = .{ pos.coords[0] - half_edge_len, pos.coords[1] - half_edge_len, pos.coords[2] + half_edge_len } },
            .{ .coords = .{ pos.coords[0] + half_edge_len, pos.coords[1] - half_edge_len, pos.coords[2] + half_edge_len } },
            .{ .coords = .{ pos.coords[0] + half_edge_len, pos.coords[1] - half_edge_len, pos.coords[2] - half_edge_len } },
            .{ .coords = .{ pos.coords[0] - half_edge_len, pos.coords[1] + half_edge_len, pos.coords[2] - half_edge_len } },
            .{ .coords = .{ pos.coords[0] - half_edge_len, pos.coords[1] + half_edge_len, pos.coords[2] + half_edge_len } },
            .{ .coords = .{ pos.coords[0] + half_edge_len, pos.coords[1] + half_edge_len, pos.coords[2] + half_edge_len } },
            .{ .coords = .{ pos.coords[0] + half_edge_len, pos.coords[1] + half_edge_len, pos.coords[2] - half_edge_len } },
        };
        return .{
            .pos = pos,
            .radius = radius,
            .shape = cube,
        };
    }

    pub fn viewMatrix(self: Self) [16]f32 {
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

pub const Shape = enum(u8) {
    CUBE,
    PYRAMID,
    SPHERE,
    CONE,

    /// Caller must free
    pub fn create(self: Shape, allocator: Allocator, res: ?usize) []V3 {
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
            .SPHERE => Sphere.create(allocator, resolution),
            .CONE => Cone.create(allocator, resolution),
        };
    }
};

const Sphere = struct {
    /// Caller must free
    pub fn create(allocator: Allocator, res: usize) []V3 {
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

const Cone = struct {
    /// Caller must free
    pub fn create(allocator: Allocator, res: usize) []V3 {
        const slices = res;
        const radius: f32 = 1.0;
        const height: f32 = 2.0;

        const vertexes = allocator.alloc(V3, slices + 2) catch unreachable;

        var idx: usize = 0;
        vertexes[idx] = .{ .coords = .{ 0, 0, height } };
        idx += 1;

        for (0..slices) |i| {
            const theta = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(slices));

            vertexes[idx] = .{ .coords = .{
                @cos(theta) * radius,
                @sin(theta) * radius,
                0,
            } };
            idx += 1;
        }

        vertexes[idx] = .{ .coords = .{ 0, 0, 0 } };
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

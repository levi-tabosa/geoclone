const geoc = @import("geoc");
const std = @import("std");
const Allocator = std.mem.Allocator;
// const grid_res = 10;
// const num_axis = 6;
const far = 40.0;
const near = 10.0;

pub const Vertex = struct {
    coords: [3]f32,
    offset: [3]f32 = .{ 0.0, 0.0, 0.0 },
};

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _logf(allocator: Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

pub const Demo = struct {
    const Self = @This();

    // geoc_instance: geoc.Geoc,
    allocator: Allocator,
    _i: f32 = 0.20,
    _H: u32 = 1,
    _W: u32 = 1,
    angle_x: f32 = 0,
    angle_z: f32 = 0,
    axis: *const []Vertex,
    grid: *const []Vertex,
    vectors: ?*[]Vertex = null,
    shapes: ?*[][]Vertex = null,

    pub fn init(allocator: Allocator) Self {
        const grid_res = 10;
        const num_axis = 6;

        const grid = &(allocator.alloc(Vertex, grid_res << 2) catch @panic("OOM"));
        // defer allocator.free(grid.*);
        const axis = &(allocator.alloc(Vertex, num_axis) catch @panic("OOM"));
        // defer allocator.free(axis.*);

        const fixed: f32 = @floatFromInt(grid_res);

        const vertex_array = [_]Vertex{
            Vertex{ .coords = .{ fixed, 0.0, 0.0 } },
            Vertex{ .coords = .{ -fixed, 0.0, 0.0 } },
            Vertex{ .coords = .{ 0.0, fixed, 0.0 } },
            Vertex{ .coords = .{ 0.0, -fixed, 0.0 } },
            Vertex{ .coords = .{ 0.0, 0.0, fixed } },
            Vertex{ .coords = .{ 0.0, 0.0, -fixed } },
        };
        for (0..num_axis) |i| {
            axis.*[i] = vertex_array[i];
        }
        _logf(allocator, "axis on demo {any}", .{axis.*});

        for (0..grid_res) |i| {
            const index: f32 = @floatFromInt(i);
            grid.*[i << 2] = Vertex{ .coords = .{ index, fixed, 0.0 } };
            grid.*[(i << 2) + 1] = Vertex{ .coords = .{ index, -fixed, 0.0 } };
            grid.*[(i << 2) + 2] = Vertex{ .coords = .{ fixed, index, 0.0 } };
            grid.*[(i << 2) + 3] = Vertex{ .coords = .{ -fixed, index, 0.0 } };
        }
        if (grid_res & 1 == 1) {
            const j = grid_res << 2;
            grid.*[j] = Vertex{ .coords = .{ fixed, fixed, 0.0 } };
            grid.*[j + 1] = Vertex{ .coords = .{ fixed, -fixed, 0.0 } };
            grid.*[j + 2] = Vertex{ .coords = .{ fixed, fixed, 0.0 } };
            grid.*[j + 3] = Vertex{ .coords = .{ -fixed, fixed, 0.0 } };
        }
        _logf(allocator, "grid on demo {any}", .{grid.*});

        return .{
            .allocator = allocator,
            .axis = axis,
            .grid = grid,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.axis.*);
        self.allocator.free(self.grid.*);
        if (self.vectors) |vecs| {
            self.allocator.free(vecs.*);
        }
        if (self.shapes) |shps| {
            self.allocator.free(shps.*);
        }
    }
};

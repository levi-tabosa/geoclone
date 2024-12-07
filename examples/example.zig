const g = @import("geoc");
const std = @import("std");
const math3d = g.math3d;
const near = 10;
const far = 35;

fn _log(txt: []const u8) void { //TODO: erase
    g.platform.log(txt);
}

fn _LOGF(allocator: std.mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

pub const std_options = .{
    .log_level = .info,
    .logFn = g.logFn,
};

const V2 = struct {
    coords: [2]f32,
    offset: [2]f32 = .{ 0.0, 0.0 },
};

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V2), //TODO reutilize
    grid_buffer: g.VertexBuffer(V2),
    vectors_buffer: g.VertexBuffer(V2),
    program: g.Program,
    geoc: g.Geoc,
    scene: *math3d.Scene,

    pub fn init(geoc_instance: g.Geoc, scene: *math3d.Scene) Self {
        geoc_instance.setDemoCallBack(.{
            .ptr = scene,
            .setAnglesFn = setAnglesFn,
            .setZoomFn = setZoomFn,
            .setInsertFn = setInsertFn,
        });

        const vertex_shader_source =
            \\attribute vec2 coords;
            \\attribute vec2 offset;
            \\void main() {
            \\    gl_Position = vec4(coords.x, coords.y, 1.0, 1.0);
            \\}
        ;
        const fragment_shader_source =
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
            \\}
        ;
        const vertex_shader = g.Shader.init(geoc_instance, g.ShaderType.Vertex, vertex_shader_source);
        defer vertex_shader.deinit();
        const fragment_shader = g.Shader.init(geoc_instance, g.ShaderType.Fragment, fragment_shader_source);
        defer fragment_shader.deinit();
        const program = g.Program.init(geoc_instance, &[_]g.Shader{ vertex_shader, fragment_shader });

        const axis_len = scene.axis.len;
        const grid_len = scene.grid.len;

        return .{
            .axis_buffer = g.VertexBuffer(V2).init(&[_]V2{V2{ .coords = .{ 0, 0 } }} ** axis_len),
            .grid_buffer = g.VertexBuffer(V2).init(&[_]V2{V2{ .coords = .{ 0, 0 } }} ** grid_len),
            .vectors_buffer = g.VertexBuffer(V2).init(&[_]V2{V2{ .coords = .{ 0, 0 } }}),
            .program = program,
            .geoc = geoc_instance,
            .scene = scene,
        };
    }

    pub fn deinit(self: *Self) void {
        self.program.deinit();
        self.axis_buffer.deinit();
    }

    pub fn draw(self: Self) void {
        const axis_len = self.scene.axis.len;
        const grid_len = self.scene.grid.len;

        var axis_array = self.geoc.allocator.alloc(V2, axis_len) catch @panic("OOM");
        defer self.geoc.allocator.free(axis_array);
        var grid_array = self.geoc.allocator.alloc(V2, grid_len) catch @panic("OOM");
        defer self.geoc.allocator.free(grid_array);

        for (0..axis_len, self.scene.axis) |i, vertex| {
            axis_array[i] = V2{ .coords = .{
                vertex.changed[0] * near / (vertex.changed[2] + far),
                vertex.changed[1] * near / (vertex.changed[2] + far),
            } };
        }

        for (0..grid_len, self.scene.grid) |i, vertex| {
            grid_array[i] = V2{ .coords = .{
                vertex.changed[0] * near / (vertex.changed[2] + far),
                vertex.changed[1] * near / (vertex.changed[2] + far),
            } };
        }

        const axis_buffer = g.VertexBuffer(V2).init(axis_array);
        defer axis_buffer.deinit();
        const grid_buffer = g.VertexBuffer(V2).init(grid_array);
        defer grid_buffer.deinit();

        self.geoc.draw(V2, self.program, axis_buffer, g.DrawMode.Lines);
        self.geoc.draw(V2, self.program, grid_buffer, g.DrawMode.Lines);
        self.drawVectors();
    }

    fn drawVectors(self: Self) void {
        if (self.scene.vectors) |vectors| {
            var vectors_array = self.geoc.allocator.alloc(V2, vectors.len) catch @panic("OOM");
            defer self.geoc.allocator.free(vectors_array);

            for (0..vectors.len, vectors) |i, vertex| {
                _LOGF(self.geoc.allocator, "vertex: {any}", .{vertex});
                vectors_array[i] = V2{ .coords = .{
                    vertex.changed[0],
                    vertex.changed[1],
                } };
            }
            _LOGF(self.geoc.allocator, "vector array: {any}", .{vectors_array});

            const vectors_buffer = g.VertexBuffer(V2).init(vectors_array);
            defer vectors_buffer.deinit();

            self.geoc.draw(V2, self.program, vectors_buffer, g.DrawMode.Lines);
        }
    }

    fn drawFn(ptr: *anyopaque) callconv(.C) void {
        const state: *State = @ptrCast(@alignCast(ptr));
        state.draw();
    }

    pub fn run(self: Self, state: g.State) void {
        self.geoc.run(state);
    }

    pub fn geocState(self: *Self) g.State {
        return .{
            .ptr = self,
            .drawFn = drawFn,
        };
    }
};
fn setAnglesFn(ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void {
    const scene: *math3d.Scene = @ptrCast(@alignCast(ptr));
    scene.setAngleZ(angle_z);
    scene.setAngleX(angle_x);
    scene.updateLines();
}

fn setZoomFn(ptr: *anyopaque, zoom: f32) callconv(.C) void {
    const scene: *math3d.Scene = @ptrCast(@alignCast(ptr));
    scene.setZoom(zoom);
    scene.updateLines();
}

fn setInsertFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    const scene: *math3d.Scene = @ptrCast(@alignCast(ptr));
    scene.addVector(x, y, z);
}

pub fn main() void {
    var engine = g.Geoc.init();
    defer engine.deinit();

    var scene = math3d.Scene.init(engine.allocator);

    var state = State.init(engine, &scene);
    defer state.deinit();

    state.run(state.geocState());
}

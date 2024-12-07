const geoc = @import("geoc");
const std = @import("std");
const demo = geoc.demo;
const near = 10;
const far = 35;

fn _log(txt: []const u8) void { //TODO: erase
    geoc.platform.log(txt);
}

fn _LOGF(allocator: std.mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch @panic("OOM"));
}

pub const std_options = .{
    .log_level = .info,
    .logFn = geoc.logFn,
};

const V2 = struct {
    coords: [2]f32,
    offset: [2]f32 = .{ 0.0, 0.0 },
};

pub const State = struct {
    const Self = @This();

    axis_buffer: geoc.VertexBuffer(V2), //TODO reutilize
    grid_buffer: geoc.VertexBuffer(V2),
    vectors_buffer: geoc.VertexBuffer(V2),
    program: geoc.Program,
    geoc_instance: geoc.Geoc,
    demo_instance: *demo.Demo,

    pub fn init(geoc_instance: geoc.Geoc, demo_instance: *demo.Demo) Self {
        geoc_instance.setDemoCallBack(.{
            .ptr = demo_instance,
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
        const vertex_shader = geoc.Shader.init(geoc_instance, geoc.ShaderType.Vertex, vertex_shader_source);
        defer vertex_shader.deinit();
        const fragment_shader = geoc.Shader.init(geoc_instance, geoc.ShaderType.Fragment, fragment_shader_source);
        defer fragment_shader.deinit();
        const program = geoc.Program.init(geoc_instance, &[_]geoc.Shader{ vertex_shader, fragment_shader });

        const axis_len = demo_instance.axis.len;
        const grid_len = demo_instance.grid.len;

        return .{
            .axis_buffer = geoc.VertexBuffer(V2).init(&[_]V2{V2{ .coords = .{ 0, 0 } }} ** axis_len),
            .grid_buffer = geoc.VertexBuffer(V2).init(&[_]V2{V2{ .coords = .{ 0, 0 } }} ** grid_len),
            .vectors_buffer = geoc.VertexBuffer(V2).init(&[_]V2{V2{ .coords = .{ 0, 0 } }}),
            .program = program,
            .geoc_instance = geoc_instance,
            .demo_instance = demo_instance,
        };
    }

    pub fn deinit(self: *Self) void {
        self.program.deinit();
        self.axis_buffer.deinit();
    }

    pub fn draw(self: Self) void {
        const axis_len = self.demo_instance.axis.len;
        const grid_len = self.demo_instance.grid.len;
        const vectors_len = self.demo_instance.vectors.items.len;

        var axis_array = self.geoc_instance.allocator.alloc(V2, axis_len) catch @panic("OOM");
        defer self.geoc_instance.allocator.free(axis_array);
        var grid_array = self.geoc_instance.allocator.alloc(V2, grid_len) catch @panic("OOM");
        defer self.geoc_instance.allocator.free(grid_array);
        var vectors_array = self.geoc_instance.allocator.alloc(V2, vectors_len) catch @panic("OOM");
        defer self.geoc_instance.allocator.free(vectors_array);

        for (0..axis_len, self.demo_instance.axis) |i, vertex| {
            axis_array[i] = V2{
                .coords = .{
                    vertex.changed[0] * near / (vertex.changed[2] + far),
                    vertex.changed[1] * near / (vertex.changed[2] + far),
                },
                .offset = .{
                    vertex.coords[0],
                    vertex.coords[1],
                },
            };
        }

        for (0..grid_len, self.demo_instance.grid) |i, vertex| {
            grid_array[i] = V2{
                .coords = .{
                    vertex.changed[0] * near / (vertex.changed[2] + far),
                    vertex.changed[1] * near / (vertex.changed[2] + far),
                },
                .offset = .{
                    vertex.coords[0],
                    vertex.coords[1],
                },
            };
        }

        _LOGF(self.geoc_instance.allocator, "Before draw: {any}", .{self.demo_instance.vectors.items});
        _LOGF(self.geoc_instance.allocator, "Vectors count: {d}", .{self.demo_instance.vectors.items.len});

        for (0..vectors_len, self.demo_instance.vectors.items) |i, vertex| {
            vectors_array[i] = V2{
                .coords = .{
                    vertex.changed[0] * near / (vertex.changed[2] + far),
                    vertex.changed[1] * near / (vertex.changed[2] + far),
                },
                .offset = .{
                    vertex.coords[0],
                    vertex.coords[1],
                },
            };
        }
        _LOGF(self.geoc_instance.allocator, "After draw: {any}", .{self.demo_instance.vectors.items});
        _LOGF(self.geoc_instance.allocator, "Vectors count: {d}", .{self.demo_instance.vectors.items.len});

        const vectors_buffer = geoc.VertexBuffer(V2).init(if (vectors_len > 0) vectors_array else &[_]V2{V2{ .coords = .{ 0, 0 } }});
        defer vectors_buffer.deinit();

        self.geoc_instance.draw(V2, self.program, vectors_buffer, geoc.DrawMode.Lines);

        const axis_buffer = geoc.VertexBuffer(V2).init(axis_array);
        defer axis_buffer.deinit();
        const grid_buffer = geoc.VertexBuffer(V2).init(grid_array);
        defer grid_buffer.deinit();

        self.geoc_instance.draw(V2, self.program, axis_buffer, geoc.DrawMode.Lines);
        self.geoc_instance.draw(V2, self.program, grid_buffer, geoc.DrawMode.Lines);
    }

    fn drawFn(ptr: *anyopaque) callconv(.C) void {
        const state: *State = @ptrCast(@alignCast(ptr));
        state.draw();
    }

    pub fn run(self: Self, state: geoc.State) void {
        self.geoc_instance.run(state);
    }

    pub fn geocState(self: *Self) geoc.State {
        return .{
            .ptr = self,
            .drawFn = drawFn,
        };
    }
};
fn setAnglesFn(ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void {
    const demo_instance: *demo.Demo = @ptrCast(@alignCast(ptr));
    demo_instance.setAngleZ(angle_z);
    demo_instance.setAngleX(angle_x);
    demo_instance.updateLines();
}

fn setZoomFn(ptr: *anyopaque, zoom: f32) callconv(.C) void {
    const demo_instance: *demo.Demo = @ptrCast(@alignCast(ptr));
    demo_instance.setZoom(zoom);
    demo_instance.updateLines();
}

fn setInsertFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    const demo_instance: *demo.Demo = @ptrCast(@alignCast(ptr));
    demo_instance.addVector(x, y, z);
}

pub fn main() void {
    var engine = geoc.Geoc.init();
    defer engine.deinit();

    var demo_instance = demo.Demo.init();

    var state = State.init(engine, &demo_instance);
    defer state.deinit();

    state.run(state.geocState());
}

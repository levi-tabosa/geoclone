const geoc = @import("geoc");
const std = @import("std");
const demo = @import("demo.zig");
const near = 10;
const far = 40;

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

const Vertex = struct {
    coords: [2]f32,
    offset: [2]f32 = .{ 0.0, 0.0 },
};

pub const State = struct {
    const Self = @This();

    vertex_buffer: geoc.VertexBuffer(Vertex),
    program: geoc.Program,
    geoc_instance: geoc.Geoc,
    demo_instance: *demo.Demo,

    pub fn init(geoc_instance: geoc.Geoc, demo_instance: *demo.Demo) Self {
        const vertex_shader_source =
            \\attribute vec2 coords;
            \\attribute vec2 offset;
            \\void main() {
            \\    gl_Position = vec4(coords.x, coords.y, 1.0, 1.0);
            \\}
        ;
        const fragment_shader_source =
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
            \\}
        ;
        const vertex_shader = geoc.Shader.init(geoc_instance, geoc.ShaderType.Vertex, vertex_shader_source);
        defer vertex_shader.deinit();
        const fragment_shader = geoc.Shader.init(geoc_instance, geoc.ShaderType.Fragment, fragment_shader_source);
        defer fragment_shader.deinit();
        const program = geoc.Program.init(geoc_instance, &[_]geoc.Shader{ vertex_shader, fragment_shader });

        return .{
            .vertex_buffer = geoc.VertexBuffer(Vertex).init(&[_]Vertex{Vertex{ .coords = .{ 0, 0 } }}),
            .program = program,
            .geoc_instance = geoc_instance,
            .demo_instance = demo_instance,
        };
    }

    pub fn deinit(self: *Self) void {
        self.program.deinit();
        self.vertex_buffer.deinit();
    }

    fn drawFn(ptr: *anyopaque) callconv(.C) void {
        const state: *State = @ptrCast(@alignCast(ptr));
        state.draw();
    }

    pub fn draw(self: Self) void {
        var t = self.geoc_instance.currentTime();
        t = (t - @floor(t)) * 0.99;
        self.demo_instance.setZ(6.28319 * t);

        const axis_len = self.demo_instance.axis.len;
        const grid_len = self.demo_instance.grid.len;

        var axis_array = self.geoc_instance.allocator.alloc(Vertex, axis_len) catch @panic("OOM");
        defer self.geoc_instance.allocator.free(axis_array);
        var grid_array = self.geoc_instance.allocator.alloc(Vertex, grid_len) catch @panic("OOM");
        defer self.geoc_instance.allocator.free(grid_array);

        for (0..axis_len, self.demo_instance.axis) |i, vertex| {
            axis_array[i] = Vertex{
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
            grid_array[i] = Vertex{
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

        self.geoc_instance.draw(Vertex, self.program, geoc.VertexBuffer(Vertex).init(axis_array), geoc.DrawMode.Lines);
        self.geoc_instance.draw(Vertex, self.program, geoc.VertexBuffer(Vertex).init(grid_array), geoc.DrawMode.Lines);
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

pub fn main() void {
    var engine = geoc.Geoc.init();
    defer engine.deinit();

    var demo_instance = demo.Demo.init();

    var state = State.init(engine, &demo_instance);
    defer state.deinit();

    state.run(state.geocState());
}

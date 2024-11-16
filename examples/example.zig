const geoc = @import("geoc");
const std = @import("std");
const demo = @import("demo.zig");

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
    demo_instance: demo.Demo,

    pub fn init(geoc_instance: geoc.Geoc, demo_instance: demo.Demo) Self {
        const vertex_shader_source =
            \\attribute vec2 coords;
            \\attribute vec2 offset;
            \\void main() {
            \\    gl_Position = vec4(coords.x + offset.x, coords.y + offset.y, 1.0, 1.0);
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

        const axis_len = demo_instance.axis.len;
        var axis_array = geoc_instance.allocator.alloc(Vertex, axis_len) catch @panic("OOM");
        defer geoc_instance.allocator.free(axis_array);

        for (0..axis_len) |i| {
            axis_array[i] = Vertex{
                .coords = .{
                    demo_instance.axis.*[i].coords[0],
                    demo_instance.axis.*[i].coords[1],
                },
                .offset = .{
                    demo_instance.axis.*[i].offset[0],
                    demo_instance.axis.*[i].offset[1],
                },
            };
        }
        _LOGF(geoc_instance.allocator, "axis on example {any}\n", .{axis_array});

        const axis_buffer = geoc.VertexBuffer(Vertex).init(axis_array);
        geoc_instance.draw(Vertex, program, axis_buffer, geoc.DrawMode.Lines);

        const grid_len = demo_instance.grid.len;
        _LOGF(geoc_instance.allocator, "grid len on example {}", .{demo_instance.grid.len});
        var grid_array = geoc_instance.allocator.alloc(Vertex, grid_len) catch @panic("OOM");
        defer geoc_instance.allocator.free(grid_array);

        _LOGF(geoc_instance.allocator, "demo.instance.grid on example {any}", .{demo_instance.grid.*});

        for (0..grid_len) |i| {
            grid_array[i] = Vertex{ .coords = .{
                demo_instance.grid.*[i].coords[0],
                demo_instance.grid.*[i].coords[1],
            }, .offset = .{
                demo_instance.grid.*[i].offset[0],
                demo_instance.grid.*[i].offset[1],
            } };
        }

        // const grid_buffer = geoc.VertexBuffer(Vertex).init(grid_array);

        return .{
            .vertex_buffer = axis_buffer,
            .program = program,
            .demo_instance = demo_instance,
            .geoc_instance = geoc_instance,
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
        _log("draw");
        var t = self.geoc_instance.currentTime();
        t = (t - std.math.floor(t)) * 0.9;

        const grid_len = self.demo_instance.grid.len;
        const axis_len = self.demo_instance.axis.len;
        _LOGF(self.geoc_instance.allocator, "grid len on example draw {}", .{grid_len});
        _LOGF(self.geoc_instance.allocator, "self.demo_instance.grid draw {any}", .{self.demo_instance.grid.*});
        _LOGF(self.geoc_instance.allocator, "axis len on example draw {}", .{axis_len});
        // _LOGF(self.geoc_instance.allocator, "self.demo_instance.axis draw {any}", .{self.demo_instance.axis.*});

        var grid_array = self.geoc_instance.allocator.alloc(Vertex, grid_len) catch @panic("OOM");
        defer self.geoc_instance.allocator.free(grid_array);
        // var axis_array = self.geoc_instance.allocator.alloc(Vertex, grid_len) catch @panic("OOM");
        // defer self.geoc_instance.allocator.free(axis_array);
        _LOGF(self.geoc_instance.allocator, "BEFORE grid on example draw {any}", .{grid_array});
        // _LOGF(self.geoc_instance.allocator, "BEFORE axis on example draw {any}", .{axis_array});

        for (0..grid_len) |i| {
            grid_array[i] = Vertex{
                .coords = .{
                    self.demo_instance.grid.*[i].coords[0],
                    self.demo_instance.grid.*[i].coords[1],
                },
            };
        }

        // for (0..axis_len) |i| {
        //     axis_array[i] = Vertex{
        //         .coords = .{
        //             self.demo_instance.axis.*[i].coords[0],
        //             self.demo_instance.axis.*[i].coords[1],
        //         },
        //     };
        // }

        // const vertex_array = &[_]Vertex{ Vertex{ .coords = .{ 0.0, -1.0 } }, Vertex{ .coords = .{ 0.0, 1.0 } }, Vertex{ .coords = .{ 1.0, 0.0 } }, Vertex{ .coords = .{ -1.0, 0.0 } } };

        _LOGF(self.geoc_instance.allocator, "AFTER grid on example draw {any}", .{grid_array});
        // _LOGF(self.geoc_instance.allocator, "AFTER axis on example draw {any}", .{axis_array});
        const grid_buffer = geoc.VertexBuffer(Vertex).init(grid_array);
        // const axis_buffer = geoc.VertexBuffer(Vertex).init(axis_array);

        self.geoc_instance.draw(Vertex, self.program, grid_buffer, geoc.DrawMode.Lines);
        // self.geoc_instance.draw(Vertex, self.program, axis_buffer, geoc.DrawMode.Lines);
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

    var demo_instance = demo.Demo.init(engine);
    defer demo_instance.deinit();

    var state = State.init(engine, demo_instance);
    defer state.deinit();

    state.run(state.geocState());
}

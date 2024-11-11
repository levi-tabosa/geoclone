const geoc = @import("geoc");
const std = @import("std");

pub const std_options = .{
    .log_level = .info,
    .logFn = geoc.logFn,
};

const Vertex = struct {
    aVertexPosition: [2]f32,
};

pub const State = struct {
    const Self = @This();

    vertex_buffer: geoc.VertexBuffer(Vertex),
    program: geoc.Program,
    geoc_instance: geoc.Geoc,

    pub fn init(geoc_instance: geoc.Geoc) Self {
        const vertexShaderSource =
            \\attribute vec4 aVertexPosition;
            \\void main() {
            \\    gl_Position = aVertexPosition;
            \\}
        ;

        const fragmentShaderSource =
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
            \\}
        ;

        const vertex_shader = geoc.Shader.init(geoc_instance, geoc.ShaderType.Vertex, vertexShaderSource);
        defer vertex_shader.deinit();
        const fragment_shader = geoc.Shader.init(geoc_instance, geoc.ShaderType.Fragment, fragmentShaderSource);
        defer fragment_shader.deinit();

        const program = geoc.Program.init(geoc_instance, &[_]geoc.Shader{ vertex_shader, fragment_shader });

        const vertex_array = [_]Vertex{
            Vertex{ .aVertexPosition = .{ 0.0, 1.0 } },
            Vertex{ .aVertexPosition = .{ -1.0, -1.0 } },
            Vertex{ .aVertexPosition = .{ 1.0, -1.0 } },
        };

        const vertex_buffer = geoc.VertexBuffer(Vertex).init(&vertex_array);

        geoc_instance.draw(Vertex, program, vertex_buffer);

        return .{
            .vertex_buffer = vertex_buffer,
            .program = program,
            .geoc_instance = geoc_instance,
        };
    }

    pub fn deinit(self: Self) void {
        self.program.deinit();
        self.vertex_buffer.deinit();
    }

    fn drawFn(ptr: *anyopaque) callconv(.C) void {
        const state: *State = @ptrCast(@alignCast(ptr));
        state.draw();
    }

    pub fn draw(self: *Self) void {
        var t = self.geoc_instance.currentTime();
        t = (t - std.math.floor(t)) * 0.9;
        self.geoc_instance.clear(t, t, t, 1);

        self.geoc_instance.draw(Vertex, self.program, self.vertex_buffer);
    }

    pub fn run(self: *Self, state: *const geoc.State) void {
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
    const engine = geoc.Geoc.init();
    // defer engine.deinit();

    var state = State.init(@constCast(&engine).*);
    // defer state.deinit();
    state.run(&state.geocState());
}

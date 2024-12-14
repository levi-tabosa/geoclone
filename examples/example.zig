const g = @import("geoc");
const std = @import("std");
const canvas = g.canvas;

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

const V3 = canvas.V3;

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V3), //TODO look into VAO and VBO
    grid_buffer: g.VertexBuffer(V3),
    vectors_buffer: g.VertexBuffer(V2),
    program: g.Program,
    geoc: g.Geoc,
    scene: *canvas.Scene,

    pub fn init(geoc_instance: g.Geoc, scene: *canvas.Scene) Self {
        geoc_instance.setSceneCallBack(.{
            .ptr = scene,
            .angles_fn_ptr = anglesFn,
            .zoom_fn_ptr = zoomFn,
            .insert_fn_ptr = insertFn,
            .clear_fn_ptr = clearFn,
            .cube_fn_ptr = cubeFn,
            .pyramid_fn_ptr = pyramidFn,
            .rotate_fn_ptr = rotateFn,
        });

        const vertex_shader_source =
            \\uniform float aspect_ratio;
            \\attribute vec3 coords;
            \\attribute vec3 changed;
            \\void main() {
            \\    float d = changed.z + 35.0;
            \\    float factor = 10.0 / d;
            \\    gl_Position = vec4(changed.x * factor, changed.y * factor * aspect_ratio, 1.0, 1.0);
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

        return .{
            .axis_buffer = g.VertexBuffer(V3).init(&scene.axis),
            .grid_buffer = g.VertexBuffer(V3).init(&scene.grid),
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
        const axis_buffer = g.VertexBuffer(V3).init(&self.scene.axis);
        defer axis_buffer.deinit();
        const grid_buffer = g.VertexBuffer(V3).init(&self.scene.grid);
        defer grid_buffer.deinit();

        self.geoc.draw(V3, self.program, axis_buffer, g.DrawMode.Lines);
        self.geoc.draw(V3, self.program, grid_buffer, g.DrawMode.Lines);

        self.drawVectors();
        self.drawShapes();
    }

    fn drawVectors(self: Self) void {
        if (self.scene.vectors) |vectors| {
            const vectors_buffer = g.VertexBuffer(V3).init(vectors);
            defer vectors_buffer.deinit();
            self.geoc.draw(V3, self.program, vectors_buffer, g.DrawMode.Lines);
        }
    }

    fn drawShapes(self: Self) void {
        if (self.scene.shapes) |shapes| {
            for (shapes) |s| {
                const shapes_buffer = g.VertexBuffer(V3).init(s);
                defer shapes_buffer.deinit();
                self.geoc.draw(V3, self.program, shapes_buffer, g.DrawMode.Line_loop);
            }
        }
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
//TODO: move these ugly fns
fn drawFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.draw();
}

fn anglesFn(ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.setAngleZ(angle_z);
    scene.setAngleX(angle_x);
    scene.updateLines();
}

fn zoomFn(ptr: *anyopaque, zoom: f32) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.setZoom(zoom);
    scene.updateLines();
}

fn insertFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.addVector(x, y, z);
}

fn clearFn(ptr: *anyopaque) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.clear();
}

fn cubeFn(ptr: *anyopaque) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.insertCube();
}

fn pyramidFn(ptr: *anyopaque) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.insertPyramid();
}

fn rotateFn(ptr: *anyopaque, indexes_ptr: [*]const u32, indexes_len: usize, x: f32, y: f32, z: f32) callconv(.C) void {
    const scene: *canvas.Scene = @ptrCast(@alignCast(ptr));
    scene.rotate(indexes_ptr, indexes_len, x, y, z);
}

pub fn main() void {
    var engine = g.Geoc.init();
    defer engine.deinit();

    var scene = canvas.Scene.init(engine.allocator);

    var state = State.init(engine, &scene);
    defer state.deinit();

    state.run(state.geocState());
}

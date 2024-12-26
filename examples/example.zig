const g = @import("geoc");
const std = @import("std");
const canvas = g.canvas;
const Scene = canvas.Scene;
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

const V3 = canvas.V3;

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V3), //TODO look into VAO and VBO
    grid_buffer: g.VertexBuffer(V3),
    // vectors_buffer: g.VertexBuffer(V3), maybe it is possible to reuse this
    // shapes_buffer: (...)
    axis_program: g.Program,
    grid_program: g.Program,
    vectors_program: g.Program,
    shapes_program: g.Program,
    geoc: g.Geoc,
    scene: *Scene,

    pub fn init(geoc_instance: g.Geoc, scene: *Scene) Self {
        const s: canvas.State = .{
            .ptr = scene,
            .set_angles_fn_ptr = setAnglesFn,
            .get_pitch_fn_ptr = getPitch,
            .zoom_fn_ptr = zoomFn,
            .insert_fn_ptr = insertFn,
            .clear_fn_ptr = clearFn,
            .set_res_fn_ptr = setResolutionFn,
            .cube_fn_ptr = cubeFn,
            .pyramid_fn_ptr = pyramidFn,
            .sphere_fn_ptr = sphereFn,
            .cone_fn_ptr = coneFn,
            .rotate_fn_ptr = rotateFn,
            .scale_fn_ptr = scaleFn,
            .translate_fn_ptr = translateFn,
        };
        geoc_instance.setScene(s);

        // _LOGF(
        //     geoc_instance.allocator,
        //     "Size of state: \t{}\nAlign of state: \t{}\n",
        //     .{
        //         @sizeOf(@TypeOf(s)),
        //         @alignOf(@TypeOf(s)),
        //     },
        // );
        // inline for (std.meta.fields(canvas.State)) |field| {
        //     _LOGF(
        //         geoc_instance.allocator,
        //         "Offset of {s}:\t{}\nAlignment :\t{}\nType :\t{any}\nValue in state:\t{}\n",
        //         .{
        //             field.name,
        //             @offsetOf(canvas.State, field.name),
        //             field.alignment,
        //             field.type,
        //             @intFromPtr(@field(s, field.name)),
        //         },
        //     );
        // }
        // _LOGF(geoc_instance.allocator, "@intFromPtr(s.ptr)\t{}\n", .{@intFromPtr(s.ptr)});

        const vertex_shader_source =
            \\uniform float aspect_ratio;
            \\uniform float near;
            \\uniform float far;
            \\attribute vec3 coords;
            \\attribute vec3 changed;
            \\
            \\void main() {
            // \\    if(changed.z < -near) {
            // \\        float factor = near / (changed.z + near);
            // \\        gl_Position = vec4(changed.xy * vec2(factor, factor * aspect_ratio), 1.0, 0.0);
            // \\        return;
            // \\    }
            // \\    float factor = near / (changed.z + far);
            // \\    gl_Position = vec4(changed.xy * vec2(factor, factor * aspect_ratio), 1.0, 1.0);
            \\   gl_Position = vec4(changed.x, changed.y * aspect_ratio, 1.0, 1.0);
            \\}
        ;

        const a_fragment_shader_source =
            \\uniform vec4 color;
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
            \\}
        ;
        const g_fragment_shader_source =
            \\uniform vec4 color;
            \\void main() {
            \\    gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
            \\}
        ;
        const v_fragment_shader_source =
            \\uniform vec4 color;
            \\void main() {
            \\    gl_FragColor = vec4(0.0, 0.0, 1.0, 1.0);
            \\}
        ;
        const s_fragment_shader_source =
            \\uniform vec4 color;
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 1.0, 0.0, 1.0);
            \\}
        ;
        const vertex_shader = g.Shader.init(geoc_instance, g.ShaderType.Vertex, vertex_shader_source);
        defer vertex_shader.deinit();

        const a_fragment_shader = g.Shader.init(geoc_instance, g.ShaderType.Fragment, a_fragment_shader_source);
        defer a_fragment_shader.deinit();
        const g_fragment_shader = g.Shader.init(geoc_instance, g.ShaderType.Fragment, g_fragment_shader_source);
        defer g_fragment_shader.deinit();
        const v_fragment_shader = g.Shader.init(geoc_instance, g.ShaderType.Fragment, v_fragment_shader_source);
        defer v_fragment_shader.deinit();
        const s_fragment_shader = g.Shader.init(geoc_instance, g.ShaderType.Fragment, s_fragment_shader_source);
        defer s_fragment_shader.deinit();

        return .{
            .axis_buffer = g.VertexBuffer(V3).init(&scene.axis),
            .grid_buffer = g.VertexBuffer(V3).init(scene.grid),
            .axis_program = g.Program.init(geoc_instance, &.{ vertex_shader, a_fragment_shader }),
            .grid_program = g.Program.init(geoc_instance, &.{ vertex_shader, g_fragment_shader }),
            .vectors_program = g.Program.init(geoc_instance, &.{ vertex_shader, v_fragment_shader }),
            .shapes_program = g.Program.init(geoc_instance, &.{ vertex_shader, s_fragment_shader }),
            .geoc = geoc_instance,
            .scene = scene,
        };
    }

    pub fn deinit(self: *Self) void {
        self.axis_program.deinit();
        self.grid_program.deinit();
        self.vectors_program.deinit();
        self.shapes_program.deinit();
        self.axis_buffer.deinit();
        self.grid_buffer.deinit();
    }

    pub fn draw(self: Self) void {
        const axis_buffer = g.VertexBuffer(V3).init(&self.scene.axis);
        defer axis_buffer.deinit();
        const grid_buffer = g.VertexBuffer(V3).init(self.scene.grid);
        defer grid_buffer.deinit();

        self.geoc.draw(V3, self.grid_program, grid_buffer, g.DrawMode.Lines);
        self.geoc.draw(V3, self.axis_program, axis_buffer, g.DrawMode.Lines);

        self.drawVectors();
        self.drawShapes();
    }

    fn drawVectors(self: Self) void {
        if (self.scene.vectors) |vectors| {
            const vectors_buffer = g.VertexBuffer(V3).init(vectors);
            defer vectors_buffer.deinit();
            self.geoc.draw(V3, self.vectors_program, vectors_buffer, g.DrawMode.Lines);
        }
    }

    fn drawShapes(self: Self) void {
        if (self.scene.shapes) |shapes| {
            for (shapes) |s| {
                const shapes_buffer = g.VertexBuffer(V3).init(s);
                defer shapes_buffer.deinit();
                self.geoc.draw(V3, self.shapes_program, shapes_buffer, g.DrawMode.Triangles);
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

fn setResolutionFn(ptr: *anyopaque, res: usize) callconv(.C) void {
    Scene.setResolution(@ptrCast(@alignCast(ptr)), res);
}

fn setAnglesFn(ptr: *anyopaque, p_angle: f32, y_angle: f32) callconv(.C) void {
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    scene.setPitch(p_angle);
    scene.setYaw(y_angle);
    scene.updateLines();
}

fn getPitch(ptr: *anyopaque) callconv(.C) f32 {
    return @as(*Scene, @ptrCast(@alignCast(ptr))).pitch;
}

fn zoomFn(ptr: *anyopaque, zoom: f32) callconv(.C) void {
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    scene.setZoom(zoom);
    scene.updateLines();
}

fn insertFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    Scene.addVector(@ptrCast(@alignCast(ptr)), x, y, z);
}

fn clearFn(ptr: *anyopaque) callconv(.C) void {
    Scene.clear(@ptrCast(@alignCast(ptr)));
}

fn cubeFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertCube(@ptrCast(@alignCast(ptr)));
}

fn pyramidFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertPyramid(@ptrCast(@alignCast(ptr)));
}

fn sphereFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertSphere(@ptrCast(@alignCast(ptr)));
}

fn coneFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertCone(@ptrCast(@alignCast(ptr)));
}

fn rotateFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, x: f32, y: f32, z: f32) callconv(.C) void {
    Scene.rotate(@ptrCast(@alignCast(ptr)), idxs_ptr, idxs_len, x, y, z);
}

fn scaleFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, factor: f32) callconv(.C) void {
    Scene.scale(@ptrCast(@alignCast(ptr)), idxs_ptr, idxs_len, factor);
}

fn translateFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, dx: f32, dy: f32, dz: f32) callconv(.C) void {
    Scene.translate(@ptrCast(@alignCast(ptr)), idxs_ptr, idxs_len, dx, dy, dz);
}

pub fn main() void {
    var engine = g.Geoc.init();
    defer engine.deinit();

    var scene = Scene.init(engine.allocator);

    var state = State.init(engine, &scene);
    defer state.deinit();

    state.run(state.geocState());
}

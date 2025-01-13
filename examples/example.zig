const g = @import("geoc");
const std = @import("std");
const canvas = g.canvas;
const Scene = canvas.Scene;

fn _log(txt: []const u8) void { //TODO: erase
    g.platform.log(txt);
}

fn _LOGF(allocator: std.mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    _log(std.fmt.allocPrint(allocator, txt, args) catch unreachable);
}

pub const std_options = .{
    .log_level = .info,
    .logFn = g.logFn,
};

const V3 = canvas.V3;

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V3),
    grid_buffer: g.VertexBuffer(V3),
    axis_program: g.Program,
    grid_program: g.Program,
    vectors_program: g.Program,
    shapes_program: g.Program,
    cameras_program: g.Program,
    geoc: g.Geoc,
    scene: *Scene,

    pub fn init(geoc_instance: g.Geoc, scene: *Scene) Self {
        const s: canvas.State = .{
            .ptr = scene,
            .set_angles_fn_ptr = setAnglesFn,
            .get_pitch_fn_ptr = getPitch,
            .get_yaw_fn_ptr = getYaw,
            .set_zoom_fn_ptr = setZoomFn,
            .insert_vector_fn_ptr = insertVectorFn,
            .insert_camera_fn_ptr = insertCameraFn,
            .cube_fn_ptr = insertCubeFn,
            .pyramid_fn_ptr = insertPyramidFn,
            .sphere_fn_ptr = insertSphereFn,
            .cone_fn_ptr = insertConeFn,
            .clear_fn_ptr = clearFn,
            .set_res_fn_ptr = setResolutionFn,
            .set_camera_fn_ptr = setCameraFn,
            .scale_fn_ptr = scaleFn,
            .rotate_fn_ptr = rotateFn,
            .translate_fn_ptr = translateFn,
        };
        geoc_instance.setScene(s);

        _LOGF(
            geoc_instance.allocator,
            "Size of Scene.State: {} \nAlign of Scene.State:{}",
            .{
                @sizeOf(@TypeOf(s)),
                @alignOf(@TypeOf(s)),
            },
        );
        inline for (std.meta.fields(canvas.State)) |field| {
            _LOGF(
                geoc_instance.allocator,
                "Offset of {s}:\t{}\nAlignment :\t{}\nType :\t{any}\nValue in state:\t{}",
                .{
                    field.name,
                    @offsetOf(canvas.State, field.name),
                    field.alignment,
                    field.type,
                    @intFromPtr(@field(s, field.name)),
                },
            );
        }

        const vertex_shader_source =
            \\uniform mat4 projection_matrix;
            \\uniform mat4 view_matrix;
            \\attribute vec3 coords;
            \\
            \\void main() {
            \\   gl_Position = projection_matrix * view_matrix * vec4(coords, 1.0);
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
            \\    gl_FragColor = vec4(0.8, 0.0, 0.3, 1.0);
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
            \\    gl_FragColor = vec4(0.627, 0.125, 0.941, 1.0);
            \\}
        ;

        const c_fragment_shader_source =
            \\uniform vec4 color;
            \\void main() {
            \\    gl_FragColor = vec4(0.8, 0.0, 1.0, 1.0);
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
        const c_fragment_shader = g.Shader.init(geoc_instance, g.ShaderType.Fragment, c_fragment_shader_source);
        defer c_fragment_shader.deinit();

        defer geoc_instance.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);

        return .{
            .axis_buffer = g.VertexBuffer(V3).init(&scene.axis),
            .grid_buffer = g.VertexBuffer(V3).init(scene.grid),
            .axis_program = g.Program.init(geoc_instance, &.{ vertex_shader, a_fragment_shader }),
            .grid_program = g.Program.init(geoc_instance, &.{ vertex_shader, g_fragment_shader }),
            .vectors_program = g.Program.init(geoc_instance, &.{ vertex_shader, v_fragment_shader }),
            .shapes_program = g.Program.init(geoc_instance, &.{ vertex_shader, s_fragment_shader }),
            .cameras_program = g.Program.init(geoc_instance, &.{ vertex_shader, c_fragment_shader }),
            .geoc = geoc_instance,
            .scene = scene,
        };
    }

    pub fn deinit(self: *Self) void {
        self.axis_program.deinit();
        self.grid_program.deinit();
        self.vectors_program.deinit();
        self.shapes_program.deinit();
        self.cameras_program.deinit();
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

        // self.geoc.draw(V3, self.grid_program, self.grid_buffer, g.DrawMode.Lines); TODO: make this work??
        // self.geoc.draw(V3, self.axis_program, self.axis_buffer, g.DrawMode.Lines);

        self.drawVectors();
        self.drawShapes();
        // self.drawCameras();
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
                self.geoc.draw(V3, self.shapes_program, shapes_buffer, g.DrawMode.TriangleFan);
            }
        }
    }

    fn drawCameras(self: Self) void {
        if (self.scene.cameras) |cameras| {
            for (cameras) |camera| {
                const cameras_buffer = g.VertexBuffer(V3).init(camera.shape); //TODO: fix
                defer cameras_buffer.deinit();
                self.geoc.draw(V3, self.cameras_program, cameras_buffer, g.DrawMode.Line_loop);
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

fn drawFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.draw();
}

fn setAnglesFn(ptr: *anyopaque, p_angle: f32, y_angle: f32) callconv(.C) void {
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    scene.setPitch(p_angle);
    scene.setYaw(y_angle);
    scene.updateViewMatrix();

    @as(
        *State,
        @fieldParentPtr("scene", @constCast(&scene)),
    ).geoc.uniformMatrix4fv(
        "view_matrix",
        false,
        &scene.view_matrix,
    );
    // state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

// fn sliceFromStringLiteral(str: []const u8) []const u8 { // :)
//     return str;
// }

fn getPitch(ptr: *anyopaque) callconv(.C) f32 {
    return @as(*Scene, @ptrCast(@alignCast(ptr))).pitch;
}

fn getYaw(ptr: *anyopaque) callconv(.C) f32 {
    return @as(*Scene, @ptrCast(@alignCast(ptr))).yaw;
}

fn setZoomFn(ptr: *anyopaque, zoom: f32) callconv(.C) void {
    return @as(*Scene, @ptrCast(@alignCast(ptr))).setZoom(zoom);
}

fn insertVectorFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    Scene.insertVector(@ptrCast(@alignCast(ptr)), x, y, z);
}

fn insertCameraFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    Scene.insertCamera(@ptrCast(@alignCast(ptr)), x, y, z);
}

fn insertCubeFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertCube(@ptrCast(@alignCast(ptr)));
}

fn insertPyramidFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertPyramid(@ptrCast(@alignCast(ptr)));
}

fn insertSphereFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertSphere(@ptrCast(@alignCast(ptr)));
}

fn insertConeFn(ptr: *anyopaque) callconv(.C) void {
    Scene.insertCone(@ptrCast(@alignCast(ptr)));
}

fn clearFn(ptr: *anyopaque) callconv(.C) void {
    Scene.clear(@ptrCast(@alignCast(ptr)));
}

fn setResolutionFn(ptr: *anyopaque, res: usize) callconv(.C) void {
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    scene.setResolution(res);
    // const state: *State = @fieldParentPtr("scene", @constCast(&scene));
    // state.axis_buffer.deinit();
    // state.grid_buffer.deinit();
    // state.axis_buffer = g.VertexBuffer(V3).init(&scene.axis);
    // state.grid_buffer = g.VertexBuffer(V3).init(scene.grid);
}

fn setCameraFn(ptr: *anyopaque, index: usize) callconv(.C) void {
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    scene.setCamera(index);
    @as(
        *State,
        @fieldParentPtr("scene", @constCast(&scene)),
    ).geoc.uniformMatrix4fv(
        "view_matrix",
        false,
        &scene.view_matrix,
    );
    // const state: *State = @fieldParentPtr("scene", @constCast(&scene));
    // state.axis_buffer.deinit();
    // state.grid_buffer.deinit();
    // state.axis_buffer = g.VertexBuffer(V3).init(&scene.axis);
    // state.grid_buffer = g.VertexBuffer(V3).init(scene.grid);
}

fn scaleFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, factor: f32) callconv(.C) void {
    Scene.scale(@ptrCast(@alignCast(ptr)), idxs_ptr, idxs_len, shorts, factor);
}

fn rotateFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, x: f32, y: f32, z: f32) callconv(.C) void {
    Scene.rotate(@ptrCast(@alignCast(ptr)), idxs_ptr, idxs_len, shorts, x, y, z);
}

fn translateFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, dx: f32, dy: f32, dz: f32) callconv(.C) void { //TODO: make this animate
    // Scene.translate(@ptrCast(@alignCast(ptr)), idxs_ptr, idxs_len, shorts, dx, dy, dz);
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    scene.translate(idxs_ptr, idxs_len, shorts, dx, dy, dz);

    @as(
        *State,
        @fieldParentPtr("scene", @constCast(&scene)),
    ).geoc.uniformMatrix4fv(
        "view_matrix",
        false,
        &scene.camera.createViewMatrix(),
    );
}

pub fn main() void {
    var engine = g.Geoc.init();
    defer engine.deinit();

    var scene = Scene.init(engine.allocator);
    defer scene.deinit();

    var state = State.init(engine, &scene);
    defer state.deinit();

    state.run(state.geocState());
}

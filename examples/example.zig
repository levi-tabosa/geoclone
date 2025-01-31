const g = @import("geoc");
const std = @import("std");
const mem = std.mem;
const canvas = g.canvas;
const Scene = canvas.Scene;

fn print(txt: []const u8) void { //TODO: erase
    g.platform.log(txt);
}

fn _LOGF(allocator: mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    print(std.fmt.allocPrint(allocator, txt, args) catch unreachable);
}

pub const std_options = .{
    .log_level = .info,
    .logFn = g.logFn,
};

const Table = struct {
    set_angles_fn_ptr: *const fn (*anyopaque, f32, f32) callconv(.C) void,
    get_pitch_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
    get_yaw_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
    set_zoom_fn_ptr: *const fn (*anyopaque, f32) callconv(.C) void,
    insert_vector_fn_ptr: *const fn (*anyopaque, f32, f32, f32) callconv(.C) void,
    insert_camera_fn_ptr: *const fn (*anyopaque, f32, f32, f32) callconv(.C) void,
    cube_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    pyramid_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    sphere_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    cone_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    clear_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
    set_res_fn_ptr: *const fn (*anyopaque, usize) callconv(.C) void,
    set_camera_fn_ptr: *const fn (*anyopaque, usize) callconv(.C) void,
    scale_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32) callconv(.C) void,
    rotate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32, f32, f32) callconv(.C) void,
    translate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32, f32, f32) callconv(.C) void,
    reflect_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, u8) callconv(.C) void,
};

const V3 = canvas.V3;

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V3),
    grid_buffer: g.VertexBuffer(V3),
    // vector_buffer: g.VertexBuffer(V3),
    // shape_buffer: g.VertexBuffer(V3),
    // camera_buffer: g.VertexBuffer(V3),
    axis_program: g.Program,
    grid_program: g.Program,
    vectors_program: g.Program,
    shapes_program: g.Program,
    cameras_program: g.Program,
    geoc: g.Geoc,
    scene: *Scene,

    pub fn init(geoc: g.Geoc, scene: *Scene) Self {
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
            \\    gl_FragColor = vec4(0.6, 0.6, 0.6, 1.0);
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
        const vertex_shader = g.Shader.init(geoc, g.ShaderType.Vertex, vertex_shader_source);
        defer vertex_shader.deinit();

        const a_fragment_shader = g.Shader.init(geoc, g.ShaderType.Fragment, a_fragment_shader_source);
        defer a_fragment_shader.deinit();
        const g_fragment_shader = g.Shader.init(geoc, g.ShaderType.Fragment, g_fragment_shader_source);
        defer g_fragment_shader.deinit();
        const v_fragment_shader = g.Shader.init(geoc, g.ShaderType.Fragment, v_fragment_shader_source);
        defer v_fragment_shader.deinit();
        const s_fragment_shader = g.Shader.init(geoc, g.ShaderType.Fragment, s_fragment_shader_source);
        defer s_fragment_shader.deinit();
        const c_fragment_shader = g.Shader.init(geoc, g.ShaderType.Fragment, c_fragment_shader_source);
        defer c_fragment_shader.deinit();

        defer geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);

        const table: Table = .{
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
            .reflect_fn_ptr = reflectFn,
        };

        inline for (std.meta.fields(Table)) |fn_ptr| {
            geoc.setFnPtr(fn_ptr.name, @intFromPtr(@field(table, fn_ptr.name)));
        }

        return .{
            .axis_buffer = g.VertexBuffer(V3).init(&scene.axis),
            .grid_buffer = g.VertexBuffer(V3).init(scene.grid),
            .axis_program = g.Program.init(geoc, &.{ vertex_shader, a_fragment_shader }),
            .grid_program = g.Program.init(geoc, &.{ vertex_shader, g_fragment_shader }),
            .vectors_program = g.Program.init(geoc, &.{ vertex_shader, v_fragment_shader }),
            .shapes_program = g.Program.init(geoc, &.{ vertex_shader, s_fragment_shader }),
            .cameras_program = g.Program.init(geoc, &.{ vertex_shader, c_fragment_shader }),
            .geoc = geoc,
            .scene = scene,
        };
    }

    pub fn deinit(self: *Self) void {
        self.axis_buffer.deinit();
        self.grid_buffer.deinit();
        self.axis_program.deinit();
        self.grid_program.deinit();
        self.vectors_program.deinit();
        self.shapes_program.deinit();
        self.cameras_program.deinit();
    }

    pub fn draw(self: *Self) void {
        self.geoc.draw(V3, self.grid_program, self.grid_buffer, g.DrawMode.Lines);
        self.geoc.draw(V3, self.axis_program, self.axis_buffer, g.DrawMode.Lines);

        self.drawVectors();
        self.drawShapes();
        self.drawCameras();
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
                const cameras_buffer = g.VertexBuffer(V3).init(camera.shape);
                defer cameras_buffer.deinit();
                self.geoc.draw(V3, self.cameras_program, cameras_buffer, g.DrawMode.LineLoop);
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

    pub fn setResolution(self: *Self, res: usize) void {
        self.grid_buffer.deinit();
        self.axis_buffer.deinit();

        self.scene.setResolution(res);

        self.axis_buffer = g.VertexBuffer(V3).init(&self.scene.axis);
        self.grid_buffer = g.VertexBuffer(V3).init(self.scene.grid);
    }
};

fn setResolutionFn(ptr: *anyopaque, res: usize) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.setResolution(res);
}

fn drawFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.draw();
}

fn setAnglesFn(ptr: *anyopaque, p_angle: f32, y_angle: f32) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.setPitch(p_angle);
    scene.setYaw(y_angle);
    scene.updateViewMatrix();
    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn getPitch(ptr: *anyopaque) callconv(.C) f32 {
    const state: *State = @ptrCast(@alignCast(ptr));
    return state.scene.pitch;
}

fn getYaw(ptr: *anyopaque) callconv(.C) f32 {
    const state: *State = @ptrCast(@alignCast(ptr));
    return state.scene.yaw;
}

fn setZoomFn(ptr: *anyopaque, zoom: f32) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.setZoom(zoom);
}

fn insertVectorFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertVector(x, y, z);
}

fn insertCameraFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void { //TODO:crashes tab after clear call on fps camera (FIX)
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertCamera(x, y, z);
}

fn insertCubeFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertCube();
}

fn insertPyramidFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertPyramid();
}

fn insertSphereFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertSphere();
}

fn insertConeFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertCone();
}

fn clearFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.clear();
}

fn setCameraFn(ptr: *anyopaque, index: usize) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.setCamera(index);
    scene.updateViewMatrix();
    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
    _LOGF(
        scene.allocator,
        \\setCamera:
        \\state ptr : {*}
        \\scene ptr : {*}
        \\axis_buffer ptr : {*}
        \\grid_buffer ptr : {*}
    ,
        .{
            &state,
            ptr,
            &state.axis_buffer,
            &state.grid_buffer,
        },
    );
}

fn scaleFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    shorts: u32,
    factor: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.scale(idxs_ptr, idxs_len, shorts, factor);
    scene.updateViewMatrix();

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn rotateFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    shorts: u32,
    x: f32,
    y: f32,
    z: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.rotate(idxs_ptr, idxs_len, shorts, x, y, z);
    scene.updateViewMatrix();

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn translateFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    shorts: u32,
    dx: f32,
    dy: f32,
    dz: f32,
) callconv(.C) void {
    const bytes = std.mem.asBytes(&struct {
        ptr: *anyopaque,
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        shorts: u32,
        dx: f32,
        dy: f32,
        dz: f32,
    }{
        .ptr = ptr,
        .idxs_ptr = idxs_ptr,
        .idxs_len = idxs_len,
        .shorts = shorts,
        .dx = dx / 25,
        .dy = dy / 25,
        .dz = dz / 25,
    });
    const args = std.mem.bytesAsSlice(u8, bytes);

    const handle = g.Interval.init("translate", @intFromPtr(&applyTranslateFn), args, 30, 25);

    _ = handle;
}

fn applyTranslateFn( //TODO: adapt fn to accepts args as u8 slice allocated on translate?
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    shorts: u32,
    dx: f32,
    dy: f32,
    dz: f32,
) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.translate(idxs_ptr, idxs_len, shorts, dx, dy, dz);
    scene.updateViewMatrix();

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn reflectFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    shorts: u32,
    coord_idx: u8,
) callconv(.C) void {
    const scene: *Scene = @alignCast(@ptrCast(ptr));

    const bytes = std.mem.asBytes(&struct {
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        shorts: u32,
        coord_idx: u8,
    }{
        .idxs_ptr = idxs_ptr,
        .idxs_len = idxs_len,
        .shorts = shorts,
        .coord_idx = coord_idx,
    });
    //TODO: somehow call destroy on this or hold memory on js side?
    const args = scene.allocator.alloc(u8, bytes.len) catch unreachable;
    std.mem.copyBackwards(u8, args, std.mem.bytesAsSlice(u8, bytes));

    // _LOGF(scene.allocator, "BEFORE INTERVAL INIT\nargs as string: {s}\nargs : {any}\nzig args slice : {any}", .{ slice, args, slice });

    const handle = g.Interval.init("apply", @intFromPtr(&applyFn), args, 30, 25);
    _ = handle;
    // maybe call this on defer block after returning copy V3[]
}

pub fn applyFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) void {
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    const Args = struct {
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        shorts: u32,
        coord_idx: u8,
    };

    const bytes = std.mem.sliceAsBytes(args_ptr[0..args_len]);
    // _LOGF(
    //     scene.allocator,
    //     "ON APPLY \n args as string: {s}\nargs : {any}\nargs as bytes string: {s}\nargs as bytes : {any}",
    //     .{ args_ptr[0..args_len], args_ptr[0..args_len], bytes, bytes },
    // );

    const val = std.mem.bytesAsValue(Args, bytes);
    // _LOGF( //TODO: maybe just print val
    //     scene.allocator,
    //     "bytesAsValue \nidxs_ptr: {} idxs_len: {} shorts: {} coord_idx: {}",
    //     .{ @intFromPtr(val.idxs_ptr), val.idxs_len, val.shorts, val.coord_idx },
    // );

    scene.reflect(val.idxs_ptr, val.idxs_len, val.shorts, val.coord_idx, -1.0);
    scene.updateViewMatrix();

    @as(
        *State,
        @fieldParentPtr("scene", @constCast(&scene)),
    ).geoc.uniformMatrix4fv(
        "view_matrix",
        false,
        &scene.view_matrix,
    );
}

pub fn applyReflectFn(ptr: *anyopaque, idxs_ptr: [*]const u32, idxs_len: usize, shorts: u32, coord_idx: u8, factor: f32) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.reflect(idxs_ptr, idxs_len, shorts, coord_idx, factor);
    scene.updateViewMatrix();
    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

pub fn main() void {
    var engine = g.Geoc.init();
    defer engine.deinit();

    var scene = Scene.init(engine.allocator);
    defer scene.deinit();

    var state = State.init(engine, &scene);
    defer state.deinit();

    engine.setStatePtr(@ptrCast(&state));

    state.run(state.geocState());
}

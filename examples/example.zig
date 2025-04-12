const std = @import("std");
const g = @import("geoc");
const animations = g.animations;
const Scene = g.canvas.Scene;
const Usage = g.BufferUsage;
const V3 = g.canvas.V3;
const AM = animations.AnimationManager(V3);
const AMArgs = animations.TrasformArgs;

fn _LOGF(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    g.platform.log(std.fmt.allocPrint(allocator, fmt, args) catch unreachable);
}

pub const std_options = std.Options{
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
    scale_fn_ptr: *const fn (*anyopaque, [*]const usize, usize, u32, f32) callconv(.C) void,
    rotate_fn_ptr: *const fn (*anyopaque, [*]const usize, usize, u32, f32, f32, f32) callconv(.C) void,
    translate_fn_ptr: *const fn (*anyopaque, [*]const usize, usize, u32, f32, f32, f32) callconv(.C) void,
    reflect_fn_ptr: *const fn (*anyopaque, [*]const usize, usize, u32, u8) callconv(.C) void,
    free_args_fn_ptr: *const fn (*anyopaque, [*]const u8, usize) callconv(.C) void,
};

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V3),
    grid_buffer: g.VertexBuffer(V3),
    vector_buffer: ?g.VertexBuffer(V3),
    shape_buffers: std.ArrayList(g.VertexBuffer(V3)),
    camera_buffers: std.ArrayList(g.VertexBuffer(V3)),
    axis_program: g.Program,
    grid_program: g.Program,
    vectors_program: g.Program,
    shapes_program: g.Program,
    cameras_program: g.Program,
    geoc: g.Geoc,
    scene: *Scene,
    animation_manager: AM,

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

        const anm_fragment_shader_source =
            \\uniform vec4 color;
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
            \\}
        ;
        const vertex_shader = g.Shader.init(g.ShaderType.Vertex, vertex_shader_source);
        defer vertex_shader.deinit();

        const a_fragment_shader = g.Shader.init(g.ShaderType.Fragment, a_fragment_shader_source);
        defer a_fragment_shader.deinit();
        const g_fragment_shader = g.Shader.init(g.ShaderType.Fragment, g_fragment_shader_source);
        defer g_fragment_shader.deinit();
        const v_fragment_shader = g.Shader.init(g.ShaderType.Fragment, v_fragment_shader_source);
        defer v_fragment_shader.deinit();
        const s_fragment_shader = g.Shader.init(g.ShaderType.Fragment, s_fragment_shader_source);
        defer s_fragment_shader.deinit();
        const c_fragment_shader = g.Shader.init(g.ShaderType.Fragment, c_fragment_shader_source);
        defer c_fragment_shader.deinit();
        const anm_fragment_shader = g.Shader.init(g.ShaderType.Fragment, anm_fragment_shader_source);
        defer anm_fragment_shader.deinit();

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
            .free_args_fn_ptr = freeArgsFn,
        };

        inline for (std.meta.fields(Table)) |field| {
            // _LOGF(geoc.allocator, "{} {s}", .{ @intFromPtr(@field(table, field.name)), field.name });
            geoc.setFnPtr(field.name, @intFromPtr(@field(table, field.name)));
        }

        const animation_program = g.Program.init(geoc, &.{ vertex_shader, anm_fragment_shader });

        return .{
            .axis_buffer = g.VertexBuffer(V3).init(&scene.axis, Usage.StaticDraw),
            .grid_buffer = g.VertexBuffer(V3).init(scene.grid, Usage.StaticDraw),
            .vector_buffer = null,
            .shape_buffers = std.ArrayList(g.VertexBuffer(V3)).init(geoc.allocator),
            .camera_buffers = std.ArrayList(g.VertexBuffer(V3)).init(geoc.allocator),
            .axis_program = g.Program.init(geoc, &.{ vertex_shader, a_fragment_shader }),
            .grid_program = g.Program.init(geoc, &.{ vertex_shader, g_fragment_shader }),
            .vectors_program = g.Program.init(geoc, &.{ vertex_shader, v_fragment_shader }),
            .shapes_program = g.Program.init(geoc, &.{ vertex_shader, s_fragment_shader }),
            .cameras_program = g.Program.init(geoc, &.{ vertex_shader, c_fragment_shader }),
            .geoc = geoc,
            .scene = scene,
            .animation_manager = AM.init(geoc.allocator, animation_program),
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

        if (self.vector_buffer) |buffer| buffer.deinit();
        for (self.shape_buffers.items) |buffer| {
            buffer.deinit();
        }
        self.shape_buffers.deinit();
        for (self.camera_buffers.items) |buffer| {
            buffer.deinit();
        }
        self.camera_buffers.deinit();

        self.animation_manager.deinit();
    }

    pub fn draw(self: Self) void {
        self.geoc.draw(V3, self.grid_program, self.grid_buffer, g.DrawMode.Lines);
        self.geoc.draw(V3, self.axis_program, self.axis_buffer, g.DrawMode.Lines);

        self.drawVectors();
        self.drawShapes();
        self.drawCameras();
    }

    fn drawVectors(self: Self) void {
        if (self.vector_buffer) |buffer| {
            self.geoc.draw(V3, self.vectors_program, buffer, g.DrawMode.Lines);
        }
    }

    fn drawShapes(self: Self) void {
        for (self.shape_buffers.items) |buffer| {
            self.geoc.draw(V3, self.shapes_program, buffer, g.DrawMode.TriangleFan);
        }
    }

    fn drawCameras(self: Self) void {
        for (self.camera_buffers.items) |buffer| {
            _LOGF(self.geoc.allocator, "{any}", .{buffer});
            self.geoc.draw(V3, self.shapes_program, buffer, g.DrawMode.TriangleFan);
        }
    }

    fn updateVectors(self: *Self, scene: *Scene, idxs_ptr: [*]const usize, vectors_count: usize) void {
        const selected = scene.allocator.alloc(V3, vectors_count * 2) catch unreachable;
        defer scene.allocator.free(selected);

        for (0..vectors_count, idxs_ptr[0..]) |i, idx| {
            selected[i * 2] = scene.vectors.items[idx * 2];
            selected[i * 2 + 1] = scene.vectors.items[idx * 2 + 1];
        }

        self.vector_buffer.?.bufferSubData(idxs_ptr[0..vectors_count], selected);
    }

    fn updateShapes(self: *Self, scene: *Scene, idxs_ptr: [*]const usize, vectors_count: usize, shapes_count: usize) void {
        const selected = scene.allocator.alloc([]V3, shapes_count) catch unreachable;
        defer scene.allocator.free(selected);

        for (vectors_count..vectors_count + shapes_count, idxs_ptr[vectors_count..]) |i, index| {
            selected[i - vectors_count] = scene.shapes.items[index];
            self.shape_buffers.items[idxs_ptr[i]].bufferData(selected[i - vectors_count], Usage.StaticDraw);
        }
    }

    fn updateCameras(self: *Self, scene: *Scene, idxs_ptr: [*]const usize, vectors_count: usize, shapes_count: usize, idxs_len: usize) void {
        const selected = scene.allocator.alloc([]V3, idxs_len - vectors_count + shapes_count) catch unreachable;
        defer scene.allocator.free(selected);

        for (vectors_count + shapes_count..idxs_len, idxs_ptr[vectors_count + shapes_count ..]) |i, index| {
            selected[i - vectors_count + shapes_count] = &scene.cameras.items[index].shape;
            self.camera_buffers.items[idxs_ptr[i]].bufferData(selected[i - vectors_count + shapes_count], Usage.StaticDraw);
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

        self.axis_buffer = g.VertexBuffer(V3).init(&self.scene.axis, Usage.StaticDraw);
        self.grid_buffer = g.VertexBuffer(V3).init(self.scene.grid, Usage.StaticDraw);
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
    if (state.vector_buffer) |buffer| {
        buffer.deinit();
    }
    state.vector_buffer = g.VertexBuffer(V3).init(state.scene.vectors.items, Usage.StaticDraw);
}

//TODO: fix crash browser tab after clearFn call on fp camera
fn insertCameraFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.insertCamera(x, y, z);
    const vertex_data = &state.scene.cameras.getLast().shape;
    state.camera_buffers.append(g.VertexBuffer(V3).init(vertex_data, Usage.StaticDraw)) catch unreachable;
}

fn insertShapeFn(ptr: *anyopaque, shape: g.canvas.Shape) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const vertex_data = state.scene.insertShape(shape);
    state.shape_buffers.append(g.VertexBuffer(V3).init(vertex_data, Usage.StaticDraw)) catch unreachable;
}
fn insertCubeFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, g.canvas.Shape.CUBE);
}

fn insertPyramidFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, g.canvas.Shape.PYRAMID);
}

fn insertSphereFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, g.canvas.Shape.SPHERE);
}

fn insertConeFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, g.canvas.Shape.CONE);
}

fn clearFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.clear();
    if (state.vector_buffer) |buffer| {
        buffer.deinit();
        state.vector_buffer = null;
    }
    for (state.shape_buffers.items) |buff| {
        buff.deinit();
    }
    state.shape_buffers.deinit();
    for (state.camera_buffers.items) |buff| {
        buff.deinit();
    }
    state.camera_buffers.deinit();
    _ = g.gpa.detectLeaks();
}

fn setCameraFn(ptr: *anyopaque, index: usize) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.setCamera(index);
    scene.updateViewMatrix();
    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn scaleFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const usize,
    idxs_len: usize,
    counts: u32,
    factor: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));

    const indexes = state.geoc.allocator.alloc(usize, idxs_len) catch unreachable;
    std.mem.copyBackwards(usize, indexes, idxs_ptr[0..idxs_len]);

    const bytes = std.mem.asBytes(&struct {
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        counts: u32,
        factor: f32,
    }{
        .idxs_ptr = indexes.ptr,
        .idxs_len = idxs_len,
        .counts = counts,
        .factor = std.math.pow(f32, factor, 1 / 25),
    });
    const args = state.geoc.allocator.dupe(u8, bytes) catch unreachable;

    // _LOGF(state.geoc.allocator, "vec is {s}", .{if (state.scene.vectors != null) "" else "not"});
    // var selected = state.geoc.allocator.alloc(V3, indexes.len) catch unreachable;
    // for (indexes, 0..indexes.len) |idx, i| {
    //     selected[i] = state.scene.vectors.?[idx];
    // }

    // _ = animations.Animat(V3).init(
    //     selected,
    //     @intCast(@intFromPtr(&applyScaleFn)),
    //     args,
    //     30,
    //     25,
    // );

    _ = g.Interval.init(@intCast(@intFromPtr(&applyScaleFn)), args, 30, 25);
}

fn applyScaleFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) callconv(.C) void {
    const Args = struct {
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        counts: u32,
        factor: f32,
    };

    const bytes = std.mem.sliceAsBytes(args_ptr[0..args_len]);
    const args = std.mem.bytesAsValue(Args, bytes);

    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;

    scene.scale(args.idxs_ptr, args.idxs_len, args.counts, args.factor);
    scene.updateViewMatrix();

    const vectors_count = args.counts >> 0x10;
    const shapes_count = args.counts & 0xFFFF;

    if (vectors_count > 0) {
        state.updateVectors(scene, args.idxs_ptr, vectors_count);
    }

    if (shapes_count > 0) {
        state.updateShapes(scene, args.idxs_ptr, vectors_count, shapes_count);
    }

    if (args.idxs_len - vectors_count + shapes_count > 0) {
        state.updateCameras(scene, args.idxs_ptr, vectors_count, shapes_count, args.idxs_len);
    }

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn rotateFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const usize,
    idxs_len: usize,
    counts: u32,
    x: f32,
    y: f32,
    z: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));

    const indexes = state.geoc.allocator.alloc(usize, idxs_len) catch unreachable;
    std.mem.copyBackwards(usize, indexes, idxs_ptr[0..idxs_len]);

    const bytes = std.mem.asBytes(&struct {
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        counts: u32,
        x: f32,
        y: f32,
        z: f32,
    }{
        .idxs_ptr = indexes.ptr,
        .idxs_len = idxs_len,
        .counts = counts,
        .x = x / 25,
        .y = y / 25,
        .z = z / 25,
    });
    const args = state.geoc.allocator.dupe(u8, bytes) catch unreachable;

    _ = g.Interval.init(@intCast(@intFromPtr(&applyRotateFn)), args, 30, 25);
}

fn applyRotateFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) callconv(.C) void {
    const Args = struct {
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        counts: u32,
        x: f32,
        y: f32,
        z: f32,
    };
    const bytes = std.mem.sliceAsBytes(args_ptr[0..args_len]);
    const args = std.mem.bytesAsValue(Args, bytes);

    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;

    scene.rotate(args.idxs_ptr, args.idxs_len, args.counts, args.x, args.y, args.z);
    scene.updateViewMatrix();

    const vectors_count = args.counts >> 0x10;
    const shapes_count = args.counts & 0xFFFF;

    if (vectors_count > 0) {
        state.updateVectors(scene, args.idxs_ptr, vectors_count);
    }

    if (shapes_count > 0) {
        state.updateShapes(scene, args.idxs_ptr, vectors_count, shapes_count);
    }

    if (args.idxs_len - vectors_count + shapes_count > 0) {
        state.updateCameras(scene, args.idxs_ptr, vectors_count, shapes_count, args.idxs_len);
    }

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn translateFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const usize,
    idxs_len: usize,
    counts: u32,
    dx: f32,
    dy: f32,
    dz: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));

    const Args = struct {
        animation_ctx: *AM.Ctx,
        dx: f32,
        dy: f32,
        dz: f32,
    };

    const animation_ctx = state.animation_manager.context(
        idxs_ptr[0..idxs_len],
        counts,
        .{
            .vectors = state.scene.vectors.items,
            .shapes = state.scene.shapes.items,
            .cameras = @as(*?[]struct { V3 }, @alignCast(@ptrCast(&state.scene.cameras.items))).*,
        },
    );

    const bytes = std.mem.asBytes(&Args{
        .animation_ctx = animation_ctx,
        .dx = dx,
        .dy = dy,
        .dz = dz,
    });

    const args = state.geoc.allocator.dupe(u8, bytes) catch unreachable;

    state.animation_manager.start(@intFromPtr(&applyTranslateFn), args[0..bytes.len]);
}

fn applyTranslateFn(
    ptr: *anyopaque,
    args_ptr: [*]const u8,
    args_len: usize,
) callconv(.C) void {
    const Args = struct {
        ctx: *AM.Ctx,
        dx: f32,
        dy: f32,
        dz: f32,
    };

    const args: *align(1) const Args = std.mem.bytesAsValue(Args, args_ptr[0..args_len]);

    const state: *State = @ptrCast(@alignCast(ptr));

    state.animation_manager.animate(
        state.geoc,
        args.ctx,
        .{ .Translate = .{ args.dx, args.dy, args.dz } },
    );
}

fn reflectFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const usize,
    idxs_len: usize,
    counts: u32,
    coord_idx: u8,
) callconv(.C) void {
    const state: *State = @alignCast(@ptrCast(ptr));
    const indexes = state.geoc.allocator.alloc(usize, idxs_len) catch unreachable;
    std.mem.copyBackwards(usize, indexes, idxs_ptr[0..idxs_len]);

    const Args = struct {
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        counts: u32,
        coord_idx: u8,
    };
    const bytes = std.mem.asBytes(&Args{
        .idxs_ptr = indexes.ptr,
        .idxs_len = idxs_len,
        .counts = counts,
        .coord_idx = coord_idx,
    });

    const args = state.geoc.allocator.dupe(u8, bytes) catch unreachable;

    _ = g.Interval.init(@intCast(@intFromPtr(&applyReflectFn)), args, 30, 25);
    // defer _ = g.Interval.init(@intFromPtr(&applyReflectFn), args, 30, 25);
}

fn applyReflectFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) callconv(.C) void { //TODO: remove
    const Args = struct {
        idxs_ptr: [*]const usize,
        idxs_len: usize,
        counts: u32,
        coord_idx: u8,
    };

    const bytes = std.mem.sliceAsBytes(args_ptr[0..args_len]);
    const args = std.mem.bytesAsValue(Args, bytes);

    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;

    scene.reflect(args.idxs_ptr, args.idxs_len, args.counts, args.coord_idx);
    scene.updateViewMatrix();

    const vectors_count = args.counts >> 0x10;
    const shapes_count = args.counts & 0xFFFF;

    if (vectors_count > 0) {
        state.updateVectors(scene, args.idxs_ptr, vectors_count);
    }

    if (shapes_count > 0) {
        state.updateShapes(scene, args.idxs_ptr, vectors_count, shapes_count);
    }

    if (args.idxs_len - vectors_count + shapes_count > 0) {
        state.updateCameras(scene, args.idxs_ptr, vectors_count, shapes_count, args.idxs_len);
    }

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn freeArgsFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const Ctx = struct {
        ctx: *AM.Ctx,
    };
    const allocator = state.animation_manager.pool.arena.allocator();

    const val: *align(1) const Ctx = std.mem.bytesAsValue(Ctx, args_ptr[0..]);

    _LOGF(allocator, "VECS : {any}", .{state.scene.vectors.items});
    state.vector_buffer.?.bufferData(state.scene.vectors.items, Usage.StaticDraw);
    state.animation_manager.clear(val.ctx);
    state.geoc.allocator.free(args_ptr[0..args_len]);
}

pub fn main() void {
    var engine = g.Geoc.init();
    defer engine.deinit();

    var scene = Scene.init(engine.allocator);
    defer scene.deinit();

    var state = State.init(engine, &scene);
    defer state.deinit();

    engine.setStatePtr(@ptrCast(&state));

    // this call stops the scope from exiting with an Exception on js target
    // TODO: implement a similar solution on native GLFW/SDL targets, maybe a loop?
    state.run(state.geocState());
}

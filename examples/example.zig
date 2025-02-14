const g = @import("geoc");
const std = @import("std");
const canvas = g.canvas;
const Scene = canvas.Scene;

fn print(txt: []const u8) void { //TODO: erase
    g.platform.log(txt);
}

fn _LOGF(allocator: std.mem.Allocator, comptime txt: []const u8, args: anytype) void { //TODO: erase
    print(std.fmt.allocPrint(allocator, txt, args) catch unreachable);
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
    scale_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32) callconv(.C) void,
    rotate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32, f32, f32) callconv(.C) void,
    translate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32, f32, f32) callconv(.C) void,
    reflect_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, u8) callconv(.C) void,
    free_fn_ptr: *const fn (*anyopaque, [*]const u8, usize) callconv(.C) void,
};

const V3 = canvas.V3;

pub const State = struct {
    const Self = @This();

    axis_buffer: g.VertexBuffer(V3),
    grid_buffer: g.VertexBuffer(V3),
    vector_buffer: ?g.VertexBuffer(V3),
    shape_buffers: ?[]g.VertexBuffer(V3),
    camera_buffers: ?[]g.VertexBuffer(V3),
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
            .free_fn_ptr = freeFn,
        };

        inline for (std.meta.fields(Table)) |field| {
            // _LOGF(geoc.allocator, "{} {s}", .{ @intFromPtr(@field(table, field.name)), field.name });
            geoc.setFnPtr(field.name, @intFromPtr(@field(table, field.name)));
        }

        return .{
            .axis_buffer = g.VertexBuffer(V3).init(&scene.axis),
            .grid_buffer = g.VertexBuffer(V3).init(scene.grid),
            .vector_buffer = null,
            .shape_buffers = null,
            .camera_buffers = null,
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
        self.axis_program.deinit();
        self.grid_program.deinit();
        self.vectors_program.deinit();
        self.shapes_program.deinit();
        self.cameras_program.deinit();
        self.axis_buffer.deinit();
        self.grid_buffer.deinit();

        if (self.vector_buffer) |buffer| {
            buffer.deinit();
        }
        if (self.shape_buffers) |buffers| {
            for (buffers) |buff| {
                buff.deinit();
            }
        }
        if (self.camera_buffers) |buffers| {
            for (buffers) |buff| {
                buff.deinit();
            }
        }
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
        if (self.shape_buffers) |buffers| {
            for (buffers) |buffer| {
                self.geoc.draw(V3, self.shapes_program, buffer, g.DrawMode.TriangleFan);
            }
        }
    }

    fn drawCameras(self: Self) void {
        if (self.camera_buffers) |buffers| {
            for (buffers) |buffer| {
                self.geoc.draw(V3, self.cameras_program, buffer, g.DrawMode.LineLoop);
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
    if (state.vector_buffer) |buffer| {
        buffer.deinit();
    }
    state.vector_buffer = g.VertexBuffer(V3).init(state.scene.vectors.?);
}

//TODO: fix crash browser tab after clearFn call on fp camera
fn insertCameraFn(ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const len = if (state.camera_buffers) |b| b.len else 0;

    var new_buffers = state.geoc.allocator.alloc(g.VertexBuffer(V3), len + 1) catch unreachable;
    state.scene.insertCamera(x, y, z);

    if (state.camera_buffers) |buffers| {
        std.mem.copyBackwards(g.VertexBuffer(V3), new_buffers, buffers);
        state.geoc.allocator.free(buffers);
    }
    new_buffers[len] = g.VertexBuffer(V3).init(state.scene.cameras.?[len].shape);

    state.camera_buffers = new_buffers;
}

fn insertShapeFn(ptr: *anyopaque, shape: canvas.Shape) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const len = if (state.shape_buffers) |b| b.len else 0;

    var new_buffers = state.geoc.allocator.alloc(g.VertexBuffer(V3), len + 1) catch unreachable;
    state.scene.insertShape(shape);

    if (state.shape_buffers) |buffers| {
        std.mem.copyBackwards(g.VertexBuffer(V3), new_buffers, buffers);
        state.geoc.allocator.free(buffers);
    }
    new_buffers[len] = g.VertexBuffer(V3).init(state.scene.shapes.?[len]);

    state.shape_buffers = new_buffers;
}

fn insertCubeFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, canvas.Shape.CUBE);
}

fn insertPyramidFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, canvas.Shape.PYRAMID);
}

fn insertSphereFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, canvas.Shape.SPHERE);
}

fn insertConeFn(ptr: *anyopaque) callconv(.C) void {
    insertShapeFn(ptr, canvas.Shape.CONE);
}

fn clearFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.scene.clear();
    if (state.vector_buffer) |buffer| {
        buffer.deinit();
        state.vector_buffer = null;
    }
    if (state.shape_buffers) |buffers| {
        for (buffers) |buff| {
            buff.deinit();
        }
        state.shape_buffers = null;
    }
    if (state.camera_buffers) |buffers| {
        for (buffers) |buff| {
            buff.deinit();
        }
        state.camera_buffers = null;
    }
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
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    counts: u32,
    factor: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;
    scene.scale(idxs_ptr, idxs_len, counts, factor);
    scene.updateViewMatrix();

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn rotateFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    counts: u32,
    x: f32,
    y: f32,
    z: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));

    const indexes = state.geoc.allocator.alloc(u32, idxs_len) catch unreachable;
    std.mem.copyBackwards(u32, indexes, idxs_ptr[0..idxs_len]);

    const bytes = std.mem.asBytes(&struct {
        idxs_ptr: [*]const u32,
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
    const slice = std.mem.bytesAsSlice(u8, bytes);
    const args = state.geoc.allocator.alloc(u8, slice.len) catch unreachable;
    std.mem.copyBackwards(u8, args, slice);

    _ = g.Interval.init(@intFromPtr(&applyRotateFn), args, 30, 25);
}

fn applyRotateFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) void {
    const Args = struct {
        idxs_ptr: [*]const u32,
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

    const selected = scene.allocator.alloc(V3, args.idxs_len) catch unreachable;
    defer scene.allocator.free(selected);

    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn translateFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    counts: u32,
    dx: f32,
    dy: f32,
    dz: f32,
) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));

    const indexes = state.geoc.allocator.alloc(u32, idxs_len) catch unreachable;

    std.mem.copyBackwards(u32, indexes, idxs_ptr[0..idxs_len]);

    const bytes = std.mem.asBytes(&struct {
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        counts: u32,
        dx: f32,
        dy: f32,
        dz: f32,
    }{
        .idxs_ptr = indexes.ptr,
        .idxs_len = idxs_len,
        .counts = counts,
        .dx = dx / 25,
        .dy = dy / 25,
        .dz = dz / 25,
    });

    const slice = std.mem.bytesAsSlice(u8, bytes);
    const args = state.geoc.allocator.alloc(u8, slice.len) catch unreachable;
    std.mem.copyBackwards(u8, args, slice);

    _ = g.Interval.init(@intFromPtr(&applyTranslateFn), args, 30, 25);
}

//TODO: refactor
fn applyTranslateFn(
    ptr: *anyopaque,
    args_ptr: [*]const u8,
    args_len: usize,
) callconv(.C) void {
    const Args = struct {
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        counts: u32,
        dx: f32,
        dy: f32,
        dz: f32,
    };

    const bytes = std.mem.sliceAsBytes(args_ptr[0..args_len]);
    const args = std.mem.bytesAsValue(Args, bytes);

    const state: *State = @ptrCast(@alignCast(ptr));
    const scene = state.scene;

    scene.translate(args.idxs_ptr, args.idxs_len, args.counts, args.dx, args.dy, args.dz);
    scene.updateViewMatrix();

    const vectors_count = args.counts >> 0x10;
    const shapes_count = args.counts & 0xFFFF;

    if (vectors_count > 0) {
        const non_origin_idxs = scene.allocator.alloc(u32, vectors_count) catch unreachable;
        defer scene.allocator.free(non_origin_idxs);

        for (0..vectors_count) |i| {
            non_origin_idxs[i] = args.idxs_ptr[i] * 2;
        }

        const selected = scene.allocator.alloc(V3, non_origin_idxs.len * 2) catch unreachable;
        defer scene.allocator.free(selected);

        for (0..non_origin_idxs.len, non_origin_idxs[0..]) |i, index| {
            selected[i * 2] = scene.vectors.?[index];
            selected[i * 2 + 1] = scene.vectors.?[index + 1];
        }

        state.vector_buffer.?.bufferSubData(args.idxs_ptr[0..vectors_count], selected);
    }
    errdefer {
        // state.vector_buffer.?.bufferData(scene.vectors.?);
        g.platform.log("Error on applyTranslateFn");
    }
    if (shapes_count > 0) {
        const selected = scene.allocator.alloc([]V3, shapes_count) catch unreachable;
        // defer scene.allocator.free(selected);

        for (vectors_count..vectors_count + shapes_count) |i| {
            selected[i - vectors_count] = scene.shapes.?[args.idxs_ptr[i]];
            state.shape_buffers.?[args_ptr[i]].bufferData(selected[i - vectors_count]);
        }
    }
    state.geoc.uniformMatrix4fv("view_matrix", false, &scene.view_matrix);
}

fn reflectFn(
    ptr: *anyopaque,
    idxs_ptr: [*]const u32,
    idxs_len: usize,
    counts: u32,
    coord_idx: u8,
) callconv(.C) void {
    const scene: *Scene = @alignCast(@ptrCast(ptr));
    const Args = struct {
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        counts: u32,
        coord_idx: u8,
    };
    const bytes = std.mem.asBytes(&Args{
        .idxs_ptr = idxs_ptr,
        .idxs_len = idxs_len,
        .counts = counts,
        .coord_idx = coord_idx,
    });

    const args = scene.allocator.alloc(u8, bytes.len) catch unreachable;
    std.mem.copyBackwards(u8, args, std.mem.bytesAsSlice(u8, bytes));

    _ = g.Interval.init(@intFromPtr(&applyReflectFn), args, 30, 25);
    // maybe call this on defer block after returning copy V3[]
}

fn applyReflectFn(ptr: *anyopaque, args_ptr: [*]const u8, args_len: usize) void { //TODO: remove
    const scene: *Scene = @ptrCast(@alignCast(ptr));
    const Args = struct {
        idxs_ptr: [*]const u32,
        idxs_len: usize,
        counts: u32,
        coord_idx: u8,
    };

    const bytes = std.mem.sliceAsBytes(args_ptr[0..args_len]);

    const val = std.mem.bytesAsValue(Args, bytes);
    scene.reflect(val.idxs_ptr, val.idxs_len, val.counts, val.coord_idx, -1.0);
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

fn freeFn(ptr: *anyopaque, mem: [*]const u8, len: usize) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    const Slice = struct {
        ptr: [*]const u32,
        len: usize,
    };
    const idxs = std.mem.bytesAsValue(Slice, mem[0..len]);
    state.geoc.allocator.free(idxs.ptr[0..idxs.len]);
    state.geoc.allocator.free(mem[0..len]);
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

const geoc = @import("../root.zig");
const std = @import("std");

const js = struct { //TODO remove all unused fn
    extern fn init() void;
    extern fn deinit() void;
    extern fn run(ptr: *anyopaque, drawFn: *const fn (ptr: *anyopaque) callconv(.C) void) void;
    extern fn time() f32;
    extern fn print(ptr: [*]const u8, len: usize) void;
    extern fn initShader(@"type": u32, ptr_source: [*]const u8, ptr_len: u32) i32;
    extern fn deinitShader(js_handle: i32) void;
    extern fn initProgram(shader1_handle: i32, shader2_handle: i32) i32;
    extern fn deinitProgram(js_handle: i32) void;
    extern fn useProgram(js_handle: i32) void;
    extern fn initVertexBuffer(data_ptr: [*]const u8, data_len: usize) i32;
    extern fn deinitVertexBuffer(js_handle: i32) void;
    extern fn bindVertexBuffer(js_handle: i32) void;
    extern fn setInterval(
        cb_name_ptr: [*]const u8,
        cb_name_len: usize,
        fn_ptr: usize,
        args_ptr: [*]const u8,
        args_len: usize,
        delay: u32,
        timeout: u32,
    ) i32;
    extern fn clearInterval(js_handle: i32) void;
    extern fn vertexAttribPointer(
        program_handle: i32,
        name_ptr: [*]const u8,
        name_len: usize,
        size: usize,
        gl_type: GLType,
        normalized: bool,
        stride: usize,
        offset: usize,
    ) void;
    extern fn setStatePtr(ptr: *anyopaque) void;
    extern fn setFnPtr(fn_name_ptr: [*]const u8, fn_name_len: usize, fn_ptr: u32) void;
    extern fn drawArrays(mode: geoc.DrawMode, first: usize, count: usize) void;
    extern fn uniformMatrix4fv(
        location_ptr: [*]const u8,
        location_len: usize,
        transpose: bool,
        value_ptr: [*]const f32,
    ) void;
};

export fn draw(
    ptr: *anyopaque,
    drawFn: *const fn (*anyopaque) callconv(.C) void,
) void {
    drawFn(ptr);
}

export fn dummy(ptr: *anyopaque, fn_ptr: *const fn (*anyopaque) callconv(.C) void) void { //TODO:MAYBE REMOVE
    fn_ptr(ptr);
}

export fn apply(
    ptr: *anyopaque,
    fn_ptr: *const fn (*anyopaque, args_ptr: [*]const u8, args_len: usize) callconv(.C) void,
    args_ptr: [*]const u8,
    args_len: usize,
) void {
    fn_ptr(ptr, args_ptr, args_len);
}

export fn setAngles(
    ptr: *anyopaque,
    set_angles_fn_ptr: *const fn (*anyopaque, f32, f32) callconv(.C) void,
    p_angle: f32,
    y_angle: f32,
) void {
    set_angles_fn_ptr(ptr, p_angle, y_angle);
}

export fn getPitch(
    ptr: *anyopaque,
    get_pitch_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
) f32 {
    return get_pitch_fn_ptr(ptr);
}

export fn getYaw(
    ptr: *anyopaque,
    get_yaw_fn_ptr: *const fn (*anyopaque) callconv(.C) f32,
) f32 {
    return get_yaw_fn_ptr(ptr);
}

export fn insertVector(
    ptr: *anyopaque,
    insert_vector_fn_ptr: *const fn (*anyopaque, f32, f32, f32) callconv(.C) void,
    x: f32,
    y: f32,
    z: f32,
) void {
    insert_vector_fn_ptr(ptr, x, y, z);
}

export fn setZoom(
    ptr: *anyopaque,
    zoom_fn_ptr: *const fn (*anyopaque, f32) callconv(.C) void,
    zoom: f32,
) void {
    zoom_fn_ptr(ptr, zoom);
}

export fn insertCamera(
    ptr: *anyopaque,
    insert_camera_fn_ptr: *const fn (*anyopaque, f32, f32, f32) callconv(.C) void,
    x: f32,
    y: f32,
    z: f32,
) void {
    insert_camera_fn_ptr(ptr, x, y, z);
}

export fn insertCube(
    ptr: *anyopaque,
    cube_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
) void {
    cube_fn_ptr(ptr);
}

export fn insertPyramid(
    ptr: *anyopaque,
    pyramid_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
) void {
    pyramid_fn_ptr(ptr);
}

export fn insertSphere(
    ptr: *anyopaque,
    sphere_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
) void {
    sphere_fn_ptr(ptr);
}

export fn insertCone(
    ptr: *anyopaque,
    cone_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
) void {
    cone_fn_ptr(ptr);
}

export fn clear(
    ptr: *anyopaque,
    clear_fn_ptr: *const fn (*anyopaque) callconv(.C) void,
) void {
    clear_fn_ptr(ptr);
}

export fn setResolution(
    ptr: *anyopaque,
    set_resolution_fn_ptr: *const fn (*anyopaque, usize) callconv(.C) void,
    res: usize,
) void {
    set_resolution_fn_ptr(ptr, res);
}

export fn setCamera(
    ptr: *anyopaque,
    set_camera_fn_ptr: *const fn (*anyopaque, usize) callconv(.C) void,
    index: usize,
) void {
    set_camera_fn_ptr(ptr, index);
}

export fn scale(
    ptr: *anyopaque,
    scale_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32) callconv(.C) void,
    indexes_ptr: [*]const u32,
    indexes_len: usize,
    shorts: u32,
    factor: f32,
) void {
    scale_fn_ptr(ptr, indexes_ptr, indexes_len, shorts, factor);
}

export fn rotate(
    ptr: *anyopaque,
    rotate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32, f32, f32) callconv(.C) void,
    indexes_ptr: [*]const u32,
    indexes_len: usize,
    shorts: u32,
    x: f32,
    y: f32,
    z: f32,
) void {
    rotate_fn_ptr(ptr, indexes_ptr, indexes_len, shorts, x, y, z);
}

export fn translate(
    ptr: *anyopaque,
    translate_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, f32, f32, f32) callconv(.C) void,
    indexes_ptr: [*]const u32,
    indexes_len: usize,
    shorts: u32,
    dx: f32,
    dy: f32,
    dz: f32,
) void {
    translate_fn_ptr(ptr, indexes_ptr, indexes_len, shorts, dx, dy, dz);
}

export fn reflect(
    ptr: *anyopaque,
    reflect_fn_ptr: *const fn (*anyopaque, [*]const u32, usize, u32, u8) callconv(.C) void,
    indexes_ptr: [*]const u32,
    indexes_len: usize,
    shorts: u32,
    coord_idx: u8,
) void {
    reflect_fn_ptr(ptr, indexes_ptr, indexes_len, shorts, coord_idx);
}

pub fn log(message: []const u8) void {
    js.print(message.ptr, message.len);
}

pub const Shader = struct {
    const Self = @This();

    js_handle: i32,

    pub fn init(geoc_instance: geoc.Geoc, @"type": geoc.ShaderType, source: []const u8) Self {
        _ = geoc_instance;

        return .{
            .js_handle = js.initShader(@intFromEnum(@"type"), source.ptr, source.len),
        };
    }

    pub fn deinit(self: Self) void {
        js.deinitShader(self.js_handle);
    }
};

pub const Program = struct {
    const Self = @This();

    js_handle: i32,

    pub fn init(shaders: []const Shader) Self {
        if (shaders.len != 2) {
            @panic("Number of shaders must be 2");
        }

        return .{
            .js_handle = js.initProgram(shaders[0].js_handle, shaders[1].js_handle),
        };
    }

    pub fn use(self: Self) void {
        js.useProgram(self.js_handle);
    }

    pub fn deinit(self: Self) void {
        js.deinitProgram(self.js_handle);
    }
};

pub const VertexBuffer = struct {
    const Self = @This();

    js_handle: i32,

    pub fn init(data: []const u8) Self {
        return .{
            .js_handle = js.initVertexBuffer(data.ptr, data.len),
        };
    }

    pub fn deinit(self: Self) void {
        js.deinitVertexBuffer(self.js_handle);
    }

    pub fn bind(self: Self) void {
        js.bindVertexBuffer(self.js_handle);
    }
};

pub const Interval = struct {
    const Self = @This();

    js_handle: i32,

    pub fn init(cb_name: []const u8, cb_fn_ptr: usize, args: []const u8, delay: u32, count: ?u32) Self {
        return .{
            .js_handle = js.setInterval(
                cb_name.ptr,
                cb_name.len,
                cb_fn_ptr,
                args.ptr,
                args.len / 4,
                delay,
                delay * (count orelse 0),
            ),
        };
    }

    pub fn clear(self: Self) void {
        js.clearInterval(self.js_handle);
    }
};

const GLType = enum(i32) { Float = 0 };

fn getGLType(comptime @"type": type) GLType {
    if (@"type" == f32) {
        return .Float;
    }

    @compileError("Unknown type for OpenGL");
}

pub const VAO = struct {
    const Self = @This();
    pub fn init() Self {
        return .{};
    }
    pub fn bind(_: Self) void {}
    pub fn deinit(_: *const Self) void {}
};

pub const State = struct {
    const Self = @This();

    pub fn init() Self {
        js.init();
        return .{};
    }

    pub fn deinit(_: Self) void {
        js.deinit();
    }

    pub fn run(_: Self, state: geoc.State) void {
        js.run(state.ptr, state.drawFn);
    }

    pub fn setStatePtr(_: Self, ptr: *anyopaque) void {
        js.setStatePtr(ptr);
    }

    pub fn setFnPtr(_: Self, fn_name: []const u8, fn_ptr: u32) void {
        js.setFnPtr(fn_name.ptr, fn_name.len, fn_ptr);
    }

    pub fn currentTime(_: Self) f32 {
        return js.time();
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        _ = r;
        _ = g;
        _ = b;
        _ = a;
    }

    pub fn vertexAttributePointer(
        _: Self,
        program: Program,
        comptime vertex: type,
        comptime field: std.builtin.Type.StructField,
        normalized: bool,
    ) void {
        const size, const gl_type = switch (@typeInfo(field.type)) {
            .Array => |array| .{ array.len, getGLType(array.child) },
            else => {
                @compileError("field must be array type");
            },
        };
        js.vertexAttribPointer(
            program.js_handle,
            field.name.ptr,
            field.name.len,
            size,
            gl_type,
            normalized,
            @sizeOf(vertex),
            @offsetOf(vertex, field.name),
        );
    }

    pub fn drawArrays(_: Self, mode: geoc.DrawMode, first: usize, count: usize) void {
        js.drawArrays(mode, first, count);
    }

    pub fn uniformMatrix4fv(
        _: Self,
        location_ptr: [*]const u8,
        location_len: usize,
        transpose: bool,
        value_ptr: [*]const f32,
    ) void {
        js.uniformMatrix4fv(location_ptr, location_len, transpose, value_ptr);
    }
};

const geoclone = @import("../root.zig");
const std = @import("std");
const canvas = geoclone.canvas;

const js = struct { //TODO remove all unused fn
    extern fn init() void;
    extern fn deinit() void;
    extern fn clear(r: f32, g: f32, b: f32, a: f32) void;
    extern fn run(ptr: *anyopaque, drawFn: *const fn (ptr: *anyopaque) callconv(.C) void) void;
    extern fn time() f32;
    extern fn _log(ptr: [*]const u8, len: usize) void;
    extern fn initShader(@"type": u32, ptr_source: [*]const u8, ptr_len: u32) i32;
    extern fn deinitShader(js_handle: i32) void;
    extern fn initProgram(shader1_handle: i32, shader2_handle: i32) i32;
    extern fn deinitProgram(js_handle: i32) void;
    extern fn useProgram(js_handle: i32) void;
    extern fn initVertexBuffer(data_ptr: [*]const u8, data_len: usize) i32;
    extern fn deinitVertexBuffer(js_handle: i32) void;
    extern fn bindVertexBuffer(js_handle: i32) void;
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
    extern fn setSceneCallBack(
        ptr: *anyopaque,
        angles_fn_ptr: *const fn (ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void,
        zoom_fn_ptr: *const fn (ptr: *anyopaque, zoom: f32) callconv(.C) void,
        insert_fn_ptr: *const fn (ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void,
        clear_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
        cube_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
        pyramid_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
    ) void;
    extern fn drawArrays(mode: geoclone.DrawMode, first: usize, count: usize) void;
};

export fn callPtr(ptr: *anyopaque, drawFn: *const fn (ptr: *anyopaque) callconv(.C) void) void {
    drawFn(ptr);
}

export fn callSetAnglesPtr(
    ptr: *anyopaque,
    angles_fn_ptr: *const fn (ptr: *anyopaque, angle_x: f32, angle_z: f32) callconv(.C) void,
    angle_x: f32,
    angle_z: f32,
) void {
    angles_fn_ptr(ptr, angle_x, angle_z);
}

export fn callSetZoomPtr(
    ptr: *anyopaque,
    zoom_fn_ptr: *const fn (ptr: *anyopaque, zoom: f32) callconv(.C) void,
    zoom: f32,
) void {
    zoom_fn_ptr(ptr, zoom);
}

export fn callInsertVector(
    ptr: *anyopaque,
    insert_fn_ptr: *const fn (ptr: *anyopaque, x: f32, y: f32, z: f32) callconv(.C) void,
    x: f32,
    y: f32,
    z: f32,
) void {
    insert_fn_ptr(ptr, x, y, z);
}

export fn callClear(
    ptr: *anyopaque,
    clear_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
) void {
    clear_fn_ptr(ptr);
}

export fn callInsertCube(
    ptr: *anyopaque,
    cube_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
) void {
    cube_fn_ptr(ptr);
}

export fn callInsertPyramid(
    ptr: *anyopaque,
    pyramid_fn_ptr: *const fn (ptr: *anyopaque) callconv(.C) void,
) void {
    pyramid_fn_ptr(ptr);
}

pub fn log(message: []const u8) void {
    js._log(message.ptr, message.len);
}

pub const Shader = struct {
    const Self = @This();

    js_handle: i32,

    pub fn init(geoc_instance: geoclone.Geoc, @"type": geoclone.ShaderType, source: []const u8) Self {
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

    pub fn run(_: Self, state: geoclone.State) void {
        js.run(state.ptr, state.drawFn);
    }

    pub fn setSceneCallBack(_: Self, state: canvas.State) void {
        js.setSceneCallBack(
            state.ptr,
            state.angles_fn_ptr,
            state.zoom_fn_ptr,
            state.insert_fn_ptr,
            state.clear_fn_ptr,
            state.cube_fn_ptr,
            state.pyramid_fn_ptr,
        );
    }

    pub fn currentTime(_: Self) f32 {
        return js.time();
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        js.clear(r, g, b, a);
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

    pub fn drawArrays(_: Self, mode: geoclone.DrawMode, first: usize, count: usize) void {
        js.drawArrays(mode, first, count);
    }
};

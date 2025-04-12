const std = @import("std");
const geoc = @import("../root.zig");
const canvas = geoc.canvas;

pub fn log(message: []u8) void {
    std.debug.print("{s}\n", .{message});
}

pub const Shader = struct {
    const Self = @This();

    pub fn init(shader_type: geoc.ShaderType, source: []const u8) Self {
        _ = shader_type;
        _ = source;

        return .{};
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

pub const Program = struct {
    const Self = @This();

    pub fn init(shaders: []const Shader) Self {
        if (shaders.len != 2) {
            @panic("Number of shaders must be 2");
        }

        return .{};
    }

    pub fn use(self: Self) void {
        _ = self;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

pub const VertexBuffer = struct {
    const Self = @This();

    pub fn init(data: []const u8, usage: geoc.BufferUsage) Self {
        _ = data;
        _ = usage;
        return .{};
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn bind(self: Self) void {
        _ = self;
    }

    pub fn bufferData(self: Self, data: []const u8, usage: geoc.BufferUsage) void {
        _ = self;
        _ = data;
        _ = usage;
    }

    pub fn bufferSubData(self: Self, indexes: []const usize, data: []const u8) void {
        _ = self;
        _ = indexes;
        _ = data;
    }
};

pub const Interval = struct {
    const Self = @This();

    pub fn init(fn_ptr: i32, args: []const u8, delay: usize, count: usize) Self {
        _ = fn_ptr;
        _ = args;
        _ = delay;
        _ = count;
        return .{};
    }

    pub fn clear(_: Self) void {}
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
        return .{};
    }

    pub fn deinit(_: Self) void {
        _ = Self;
    }

    pub fn run(_: Self, state: geoc.State) void {
        _ = state;
        std.debug.print("native run :)\n\n", .{});
    }

    pub fn setStatePtr(_: Self, ptr: *anyopaque) void {
        _ = ptr;
    }

    pub fn setFnPtr(_: Self, fn_name: []const u8, fn_ptr: usize) void {
        _ = fn_name;
        _ = fn_ptr;
    }

    pub fn currentTime(_: Self) f32 {
        return @floatFromInt(std.time.timestamp());
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        std.debug.print("clear {} {} {} {} :-(\n", .{ r, g, b, a });
    }

    pub fn vertexAttributePointer(
        _: Self,
        program: Program,
        comptime vertex: type,
        comptime field: std.builtin.Type.StructField,
        normalized: bool,
    ) void {
        const size, const gl_type = switch (@typeInfo(field.type)) {
            .array => |array| .{ array.len, getGLType(array.child) },
            else => {
                @compileError("field must be array type");
            },
        };

        std.debug.print(
            "vertexAttributePointer {any} {any} {s} {d} {} {d} {} {d}\n",
            .{
                program,
                vertex,
                field.name,
                size,
                gl_type,
                @offsetOf(vertex, field.name),
                normalized,
                @sizeOf(vertex),
            },
        );
    }

    pub fn uniformMatrix4fv(_: Self, location: []const u8, transpose: bool, value_ptr: [*]const f32) void {
        _ = location;
        _ = transpose;
        _ = value_ptr;
    }

    pub fn drawArrays(_: Self, mode: geoc.DrawMode, first: usize, count: usize) void {
        std.debug.print("drawArrays {} {d} {d}\n", .{ mode, first, count });
    }
};

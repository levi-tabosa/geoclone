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

    pub fn init(data: []const u8) Self {
        _ = data;
        return .{};
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn bind(self: Self) void {
        _ = self;
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
        return .{};
    }

    pub fn deinit(_: Self) void {
        _ = Self;
    }

    pub fn run(_: Self, state: *const geoc.State) void {
        _ = state;
        std.debug.print("native run :)\n\n", .{});
    }

    pub fn currentTime(_: Self) f32 {
        return @floatFromInt(std.time.timestamp());
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        std.debug.print("clear {} {} {} {} :-(\n", .{ r, g, b, a });
    }
};

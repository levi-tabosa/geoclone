const std = @import("std");
const geoc = @import("../root.zig");

const Shader = struct {
    const Self = @This();

    pub fn init(shader_type: geoc.ShaderType, source: []const u8) Self {
        _ = shader_type;
        _ = source;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
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
        std.debug.print("native run :)-\n", .{});
    }

    pub fn currentTime(_: Self) f32 {
        return std.time.milliTimestamp() + 0.1;
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        std.debug.print("clear {} {} {} {} :-(\n", .{ r, g, b, a });
    }
};

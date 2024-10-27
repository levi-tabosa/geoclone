const builtin = @import("builtin");

const platform = switch (builtin.target.isWasm()) {
    true => @import("platform/web.zig"),
    false => @import("platform/native.zig"),
};

pub const ShaderType = enum { Vertex, Fragment };

pub const Shader = struct {
    const Self = @This();

    platform: platform.Shader,

    pub fn init(shader_type: ShaderType, source: []const u8) Self {
        return .{
            .platform = platform.Shader.init(shader_type, source),
        };
    }

    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }
};

pub const State = struct {
    const Self = @This();

    ptr: *anyopaque,
    drawFn: *const fn (ptr: *anyopaque) callconv(.C) void,

    pub fn draw(self: *Self) void {
        self.drawFn(self.ptr);
    }
};

pub const Geoc = struct {
    const Self = @This();

    platform: platform.State,

    pub fn init() Self {
        return .{ .platform = platform.State.init() };
    }

    pub fn deinit(self: *Self) void {
        self.platform.deinit();
    }

    pub fn run(self: *Self, state: *const State) void {
        self.platform.run(state);
    }

    pub fn currentTime(self: Self) f32 {
        return self.platform.currentTime();
    }

    pub fn clear(self: Self, r: f32, g: f32, b: f32, a: f32) void {
        self.platform.clear(r, g, b, a);
    }

    pub fn draw(self: *anyopaque) void {
        _ = self;
    }
};

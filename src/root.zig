const builtin = @import("builtin");
const platform = switch (builtin.target.isWasm()) {
    true => @import("platform/web.zig"),
    false => @import("platform/native.zig"),
};
pub fn draw(self: *anyopaque) void {
    _ = self;
}

pub const State = struct {
    const Self = @This();

    ptr: *anyopaque,
    drawFn: *const fn (ptr: *anyopaque) void,

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

    pub fn run(self: *Self, state: State) void {
        self.platform.run(state);
    }

    pub fn clear(self: Self, r: f32, g: f32, b: f32, a: f32) void {
        self.platform.clear(r, g, b, a);
    }
};

pub fn main() void {
    const state = State.init();
    _ = state;
}

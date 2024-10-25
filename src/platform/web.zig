const geoc = @import("../root.zig");

extern fn geocInit() void;
extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
extern fn glClearBits(bits: i32) void;
extern fn geocRun(ptr: *anyopaque, drawFn: *const fn (*anyopaque) void) void;

pub const State = struct {
    const Self = @This();

    pub fn init() Self {
        geocInit();
        return .{};
    }

    pub fn deinit(_: Self) void {
        _ = Self;
    }

    pub fn run(_: Self, state: geoc.State) void {
        geocRun(state.ptr, state.drawFn);
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        glClearColor(r, g, b, a);
    }
};

const geoc = @import("../root.zig");

const js = struct {
    extern fn geocInit() void;
    extern fn geocDeinit() void;
    extern fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
    extern fn clearBits(bits: i32) void;
    extern fn geocRun(ptr: *anyopaque, drawFn: *const fn (ptr: *anyopaque) callconv(.C) void) void;
    extern fn geocTime() f32;
    extern fn printSlice(ptr: [*]const u8, len: u32) void;
};

export fn callPtr(ptr: *anyopaque, drawFn: *const fn (ptr: *anyopaque) callconv(.C) void) void {
    drawFn(ptr);
}

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
        js.geocInit();
        return .{};
    }

    pub fn deinit(self: Self) void {
        js.geocDeinit();
        _ = self;
    }

    pub fn run(_: Self, state: *const geoc.State) void {
        js.geocRun(state.ptr, state.drawFn);
    }

    pub fn currentTime(_: Self) f32 {
        return js.geocTime();
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        js.clearColor(r, g, b, a);
        js.clearBits(0x00004000);
    }

    pub fn print(_: Self, string: []const u8) void {
        js.printSlice(string.ptr, string.len);
    }
};

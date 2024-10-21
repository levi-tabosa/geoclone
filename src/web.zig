extern fn geocInit() void;
extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
extern fn glClearBits(bits: i32) void;
extern fn printSlice(ptr: [*c]const u8, len: usize) void;

pub const State = struct {
    const Self = @This();

    pub fn init() Self {
        geocInit();
        clear(1.0, 0.0, 0.0, 1.0);
        print("hello world!");
        return .{};
    }

    pub fn deinit(_: *Self) void {
        _ = Self;
    }
};

pub fn clear(r: f32, g: f32, b: f32, a: f32) void {
    glClearColor(r, g, b, a);
}

pub fn print(str: []const u8) void {
    printSlice(str.ptr, str.len);
}

pub fn main() void {
    const state = State.init();
    _ = state;
}

const std = @import("std");

// const c = @cImport({
//     @cInclude("GL/glew.h");
//     @cInclude("GL/glfw3.h");
//     @cInclude("GL/gl.h");
// });

pub const State = struct {
    const Self = @This();
    pub fn init() Self {
        return .{};
    }

    pub fn deinit() void {
        _ = Self;
    }

    // pub fn glClearColor(r: f32, g: f32, b: f32, a: f32) void {
    //     c.glClearColor(r, g, b, a);
    //     c.glClear(c.GL_COLOR_BUFFER_BIT);
    // }
};

pub fn main() void {
    std.debug.print("hello-\n", .{});
}

const std = @import("std");
const geoc = @import("../root.zig");

pub const State = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(_: Self) void {
        _ = Self;
    }

    pub fn run(_: Self, event_handler: fn () void) void {
        _ = event_handler;
        std.debug.print("native run :)-\n", .{});
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        std.debug.print("clear {} {} {} {} :-(\n", .{ r, g, b, a });
    }
};

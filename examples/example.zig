const geoc = @import("geoc");
const std = @import("std");

fn drawFn(ptr: *anyopaque) callconv(.C) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.draw();
}

pub const State = struct {
    const Self = @This();

    engine: *geoc.Geoc,

    pub fn init(engine: *geoc.Geoc) Self {
        return .{ .engine = engine };
    }

    pub fn draw(self: *Self) void {
        // var t = self.engine.currentTime();
        // t *= 1.0;
        // t = t - std.math.floor(t);
        // t = t * 0.3;
        // self.engine.clear(t, t, t, 1.0);
        self.engine.clear(1, 0, 0, 1.0);
    }

    pub fn run(self: *Self, state: *const geoc.State) void {
        self.engine.run(state);
    }

    pub fn geocState(self: *Self) geoc.State {
        return .{ .ptr = self, .drawFn = drawFn };
    }
};

pub fn main() void {
    var g = geoc.Geoc.init();
    defer g.deinit();

    var state = State.init(&g);
    state.run(&state.geocState());
    state.draw();
}

const geoc = @import("geoc");

// extern fn printSlice(n: [*c]const u8, len: usize) void;

fn drawFn(ptr: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(ptr));
    state.draw();
}

pub const State = struct {
    const Self = @This();

    engine: geoc.Geoc,

    pub fn init(engine: geoc.Geoc) Self {
        return .{ .engine = engine };
    }

    pub fn draw(self: *Self) void {
        self.engine.clear(1, 0, 0, 1);
    }
    pub fn geocState(self: *Self) geoc.State {
        return .{ .ptr = self, .drawFn = drawFn };
    }
};

pub fn main() void {
    var g = geoc.Geoc.init();
    defer g.deinit();

    var state = State.init(g);
    const s = state.geocState();
    state.draw();
    _ = s;
}

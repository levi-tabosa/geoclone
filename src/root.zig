const std = @import("std");
const builtin = @import("builtin");
pub const canvas = @import("geometry/canvas.zig");
pub const animations = @import("animations/animations.zig");

pub const platform = switch (builtin.cpu.arch) {
    .wasm32 => @import("platform/web.zig"),
    else => @import("platform/native.zig"),
};

pub var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;

// used in example.zig, prevents build error if gpa is used
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ switch (scope) {
        .geoclone, .geoc, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "); ";

    const prefix = "[" ++ comptime level.asText() ++ "]" ++ scope_prefix;

    const formatStr = prefix ++ format ++ "\n";
    switch (builtin.cpu.arch) {
        .wasm32 => {
            platform.log(std.fmt.allocPrint(gpa.allocator(), formatStr, args) catch unreachable);
        },
        else => {
            const stderr = std.io.getStdErr().writer();
            nosuspend stderr.print(formatStr, args) catch return;
        },
    }
}

pub const ShaderType = enum(u8) { Vertex = 0, Fragment = 1 };

pub const DrawMode = enum(u8) {
    Points = 0,
    Lines = 1,
    LineLoop = 2,
    LineStrip = 3,
    Triangles = 4,
    TriangleString = 5,
    TriangleFan = 6,
};

pub const BufferUsage = enum(u8) {
    StaticDraw = 0,
    DynamicDraw = 1,
    StreamDraw = 2,
};

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

pub const Program = struct {
    const Self = @This();

    platform: platform.Program,

    pub fn init(instance: Geoc, shaders: []const Shader) Self {
        const platform_shaders = instance.allocator.alloc(platform.Shader, shaders.len) catch unreachable;
        defer instance.allocator.free(platform_shaders);
        for (0..shaders.len) |i| {
            platform_shaders[i] = shaders[i].platform;
        }
        return .{
            .platform = platform.Program.init(platform_shaders),
        };
    }

    pub fn use(self: Self) void {
        self.platform.use();
    }

    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }
};

pub fn VertexBuffer(comptime vertex: type) type {
    return struct {
        const Self = @This();

        platform: platform.VertexBuffer,
        count: usize,

        pub fn init(data: []const vertex, usage: BufferUsage) Self {
            return .{
                .platform = platform.VertexBuffer.init(std.mem.sliceAsBytes(data), usage),
                .count = data.len,
            };
        }

        pub fn deinit(self: Self) void {
            self.platform.deinit();
        }

        pub fn bind(self: Self) void {
            self.platform.bind();
        }

        pub fn bufferData(self: Self, data: []const vertex, usage: BufferUsage) void {
            self.platform.bufferData(std.mem.sliceAsBytes(data), usage);
        }

        pub fn bufferSubData(self: Self, indexes: []const usize, data: []const vertex) void {
            self.platform.bufferSubData(indexes, std.mem.sliceAsBytes(data));
        }
    };
}

pub const Interval = struct {
    const Self = @This();

    platform: platform.Interval,

    pub fn init(fn_ptr: i32, args: []const u8, delay: usize, count: usize) Self {
        return .{
            .platform = platform.Interval.init(
                fn_ptr,
                args,
                delay,
                count,
            ),
        };
    }

    pub fn clear(self: Self) void {
        self.platform.clear();
    }
};

pub const VAO = struct {
    const Self = @This();

    platform: platform.VAO,

    pub fn init() Self {
        return .{
            .platform = platform.VAO.init(),
        };
    }

    pub fn bind(self: Self) void {
        self.platform.bind();
    }

    pub fn deinit(self: *Self) void {
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

    allocator: std.mem.Allocator,
    platform: platform.State,

    pub fn init() Self {
        return .{
            .allocator = gpa.allocator(),
            .platform = platform.State.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.platform.deinit();
    }

    pub fn run(self: Self, state: State) void {
        self.platform.run(state);
    }

    pub fn setStatePtr(self: Self, state: *anyopaque) void {
        self.platform.setStatePtr(state);
    }

    pub fn setFnPtr(self: Self, fn_name: []const u8, fn_ptr: usize) void {
        self.platform.setFnPtr(fn_name, fn_ptr);
    }

    pub fn currentTime(self: Self) f32 {
        return self.platform.currentTime();
    }

    pub fn clear(self: Self, r: f32, g: f32, b: f32, a: f32) void {
        self.platform.clear(r, g, b, a);
    }

    pub fn draw(self: Self, comptime vertex: type, program: Program, buffer: VertexBuffer(vertex), mode: DrawMode) void {
        program.use();
        buffer.bind();

        inline for (std.meta.fields(vertex)) |field| {
            self.platform.vertexAttributePointer(program.platform, vertex, field, false);
        }

        self.platform.drawArrays(mode, 0, buffer.count);
    }

    pub fn uniformMatrix4fv(
        self: Self,
        location: []const u8,
        transpose: bool,
        value_ptr: [*]const f32,
    ) void {
        self.platform.uniformMatrix4fv(location, transpose, value_ptr);
    }
};

const std = @import("std");
const builtin = @import("builtin");
pub const demo = @import("demo");
pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const platform = switch (builtin.target.isWasm()) {
    true => @import("platform/web.zig"),
    false => @import("platform/native.zig"),
};

pub fn logFn(comptime level: std.log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const scope_prefix = "(" ++ switch (scope) {
        .geoclone, .geoc, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "); ";

    const prefix = "[" ++ comptime level.asText() ++ "]" ++ scope_prefix;

    const formatStr = prefix ++ format ++ "\n";
    if (builtin.target.isWasm()) {
        platform.log(std.fmt.allocPrint(gpa.allocator(), formatStr, args) catch return);
    } else {
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(formatStr, args) catch return;
    }
}

pub const ShaderType = enum(u32) { Vertex = 0, Fragment = 1 };

pub const DrawMode = enum(u32) {
    Points = 0,
    Lines = 1,
    Line_loop = 2,
    Line_strip = 3,
    Triangles = 4,
    Triangle_string = 5,
    Triangle_fan = 6,
};

pub const Shader = struct {
    const Self = @This();

    platform: platform.Shader,

    pub fn init(geoc_instance: Geoc, shader_type: ShaderType, source: []const u8) Self {
        return .{
            .platform = platform.Shader.init(geoc_instance, shader_type, source),
        };
    }

    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }
};

pub const Program = struct {
    const Self = @This();

    platform: platform.Program,

    pub fn init(geoc_instance: Geoc, shaders: []const Shader) Self {
        const platform_shaders = geoc_instance.allocator.alloc(platform.Shader, shaders.len) catch @panic("OOM");
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

pub fn VertexBuffer(comptime vertex: type) type {
    return struct {
        const Self = @This();

        platform: platform.VertexBuffer,
        count: usize,

        pub fn init(data: []const vertex) Self {
            const aux: [*c]const u8 = @ptrCast(data.ptr);
            return .{
                .platform = platform.VertexBuffer.init(aux[0 .. data.len * @sizeOf(vertex)]),
                .count = data.len,
            };
        }

        pub fn bind(self: Self) void {
            self.platform.bind();
        }

        pub fn deinit(self: Self) void {
            self.platform.deinit();
        }
    };
}

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
    allocator: std.mem.Allocator,

    pub fn init() Self {
        return .{
            .platform = platform.State.init(),
            .allocator = gpa.allocator(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.platform.deinit();
    }

    pub fn run(self: Self, state: State) void {
        self.platform.run(state);
    }

    pub fn setDemoCallBack(self: Self, state: demo.State) void {
        self.platform.setDemoCallBack(state);
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
};

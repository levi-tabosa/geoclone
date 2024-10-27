const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("examples/example.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("geoc", b.addModule("geoc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const dist_step = b.step("dist", "Makes dist");

    const remove_out = b.addRemoveDirTree(std.fs.path.join(b.allocator, &.{ b.install_prefix, "/dist" }) catch @panic("oom"));

    if (target.result.isWasm()) {
        const install_dir = b.addInstallDirectory(.{
            .source_dir = b.path("dir"),
            .install_dir = .{ .custom = "" },
            .install_subdir = "dist",
        });
        install_dir.step.dependOn(&remove_out.step);
        dist_step.dependOn(&install_dir.step);
        exe.rdynamic = true;
    } else {
        dist_step.dependOn(&remove_out.step);
        dist_step.dependOn(&b.addRunArtifact(exe).step);
    }
    dist_step.dependOn(&b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{ .custom = "dist" },
        },
    }).step);

    b.installArtifact(exe);
}

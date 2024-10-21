const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const web_exe = b.addExecutable(.{ .name = "web", .root_source_file = b.path("src/web.zig"), .target = target, .optimize = optimize, .single_threaded = true });

    web_exe.root_module.addImport("geoc", b.addModule("geoc", .{
        .root_source_file = b.path("src/geoc.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true, //TODO: maybe be doing nothing
    }));

    const native_exe = b.addExecutable(.{
        .name = "native",
        .root_source_file = b.path("src/native.zig"),
        .target = target,
        .optimize = optimize,
    });

    const dist_step = b.step("dist", "Makes dist");

    dist_step.dependOn(&b.addRemoveDirTree(b.install_prefix).step);

    if (target.result.isWasm()) {
        // web_exe_step =

        dist_step.dependOn(&web_exe.step);
        dist_step.dependOn(&b.addInstallArtifact(web_exe, .{
            .dest_dir = .{
                .override = .{ .custom = "dist" },
            },
        }).step);
        dist_step.dependOn(&b.addInstallDirectory(.{
            .source_dir = b.path("dir"),
            .install_dir = .{ .custom = "" },
            .install_subdir = "dist",
        }).step);

        b.installArtifact(web_exe);
    } else {
        dist_step.dependOn(&b.addRunArtifact(native_exe).step);
        dist_step.dependOn(&b.addInstallArtifact(native_exe, .{
            .dest_dir = .{
                .override = .{ .custom = "dist" },
            },
        }).step);
        b.installArtifact(native_exe);
    }

    // if (b.args) |args| {
    //     native_run_cmd.addArgs(args);
    // }

    const run_exe_unit_tests = b.addRunArtifact(b.addTest(.{
        .root_source_file = b.path("src/web.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // const exec = b.addExecutable(.{ .name = "test", .target = target, .optimize = optimize }); // run c cpp
    // exec.addCSourceFile(.{ .file = b.path("examples/test.c"), .flags = &.{"-std=c99"} });
    // exec.linkSystemLibrary("c");
    // const runc_cmd = b.addRunArtifact(exec);
    // const testc_step = b.step("testc", "Test the program");
    // testc_step.dependOn(&runc_cmd.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const exe = createExecutable(b, target, optimize);

    setupDistributionSteps(b, exe, target);

    b.installArtifact(exe);

    setupWasmFileStep(b, exe);

    setupJSFileStep(b);
}

fn createExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("examples/example.zig"),
        .target = target,
        .optimize = optimize,
    });
    const geoc = b.addModule("geoc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // geoc.addImport("demo", b.addModule("demo", .{
    //     .root_source_file = b.path("examples/demo.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // }));
    exe.root_module.addImport("geoc", geoc);

    return exe;
}

fn setupDistributionSteps(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
) void {
    const dist_step = b.step("dist", "Makes dist");

    const dist_path = std.fs.path.join(b.allocator, &.{ b.install_prefix, "/dist" }) catch @panic("oom");
    const remove_out = b.addRemoveDirTree(dist_path);

    if (target.result.isWasm()) {
        setupWasmDistribution(b, dist_step, remove_out, exe);
    } else {
        setupNativeDistribution(b, dist_step, remove_out, exe);
    }

    dist_step.dependOn(&b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{ .custom = "dist" },
        },
    }).step);
}

fn setupWasmDistribution(
    b: *std.Build,
    dist_step: *std.Build.Step,
    remove_out: *std.Build.Step.RemoveDir,
    exe: *std.Build.Step.Compile,
) void {
    const install_dir = b.addInstallDirectory(.{
        .source_dir = b.path("dir"),
        .install_dir = .{
            .custom = "",
        },
        .install_subdir = "dist",
    });
    install_dir.step.dependOn(&remove_out.step);
    dist_step.dependOn(&install_dir.step);
    exe.rdynamic = true;
}

fn setupNativeDistribution(
    b: *std.Build,
    dist_step: *std.Build.Step,
    remove_out: *std.Build.Step.RemoveDir,
    exe: *std.Build.Step.Compile,
) void {
    dist_step.dependOn(&remove_out.step);
    dist_step.dependOn(&b.addRunArtifact(exe).step);
}

fn setupWasmFileStep(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
) void {
    const only_wasm_step = b.step("justw", "regenerates wasm file");

    const wasm_path = std.fs.path.join(b.allocator, &.{ b.install_prefix, "/dist/example.wasm" }) catch @panic("OOM");
    const remove_wasm = b.addRemoveDirTree(wasm_path);

    only_wasm_step.dependOn(&remove_wasm.step);
    only_wasm_step.dependOn(&b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{ .custom = "dist" },
        },
    }).step);
}

fn setupJSFileStep(
    b: *std.Build,
) void {
    const only_js_step = b.step("justjs", "regenerates js file");

    const js_path = std.fs.path.join(b.allocator, &.{ b.install_prefix, "dist/geoc.js" }) catch @panic("OOM");
    const remove_js = b.addRemoveDirTree(js_path);

    only_js_step.dependOn(&remove_js.step);
    only_js_step.dependOn(&b.addInstallFile(
        b.path("dir/geoc.js"),
        "dist/geoc.js",
    ).step);
}

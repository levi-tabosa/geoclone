const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const exe = createExecutable(b, target, optimize);

    setupDistributionSteps(b, exe, target);

    b.installArtifact(exe);

    setupWasmFileStep(b, exe);

    setupJSFileStep(b);

    setupCSSFileStep(b);
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

    // const animations = b.addModule("animations", .{
    //     .root_source_file = b.path("src/animations/animations.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // exe.root_module.addImport("animations", animations);

    exe.root_module.addImport("geoc", geoc);

    return exe;
}

fn setupDistributionSteps(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
) void {
    const dist_step = b.step("dist", "Makes dist");

    const remove_out = b.addRemoveDirTree(b.path("zig-out/dist"));

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
        .source_dir = b.path("docs"),
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

    const remove_wasm = b.addRemoveDirTree(b.path("zig-out/dist/example.wasm"));

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

    const remove_js = b.addRemoveDirTree(b.path("zig-out/dist/geoc.js"));

    only_js_step.dependOn(&remove_js.step);
    only_js_step.dependOn(&b.addInstallFile(
        b.path("docs/geoc.js"),
        "dist/geoc.js",
    ).step);
}

fn setupCSSFileStep(
    b: *std.Build,
) void {
    const only_css_step = b.step("style", "regenerates css file");

    const remove_css = b.addRemoveDirTree(b.path("zig-out/dist/geoc.css"));

    only_css_step.dependOn(&remove_css.step);
    only_css_step.dependOn(&b.addInstallFile(
        b.path("docs/geoc.css"),
        "dist/geoc.css",
    ).step);
}

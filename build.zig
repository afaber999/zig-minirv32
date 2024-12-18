const std = @import("std");

fn build_sample(b: *std.Build, comptime sample_dir_name: []const u8) *std.Build.Step.Run {
    const sample_dir = "./samples/" ++ sample_dir_name ++ "/";
    var something = b.addSystemCommand(&.{ "zig", "build" });
    something.setCwd(b.path(sample_dir));
    something.addCheck(.{ .expect_term = .{ .Exited = 0 } });
    something.has_side_effects = true;
    return something;
}

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.

    const samples = [_][]const u8{ "hello", "mandelbrot", "shell" };

    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigrv32ima",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    inline for (samples) |sample_name| {
        // add build.zig for each sample
        const sample_step = build_sample(b, sample_name);
        exe.step.dependOn(&sample_step.step);

        // add run step for each sample
        const run_cmd1 = b.addRunArtifact(exe);
        run_cmd1.step.dependOn(b.getInstallStep());
        run_cmd1.addArg("./samples/" ++ sample_name ++ "/zig-out/bin/" ++ sample_name ++ ".bin");

        const run_step1 = b.step("run_" ++ sample_name, "Run the sample app");
        run_step1.dependOn(&run_cmd1.step);

        const qemu = b.addSystemCommand(&[_][]const u8{
            "qemu-system-riscv32",
        });
        qemu.addArg("-machine");
        qemu.addArg("virt");
        qemu.addArg("-nographic");
        qemu.addArg("-bios");
        qemu.addArg("./samples/" ++ sample_name ++ "/zig-out/bin/" ++ sample_name ++ ".bin");

        const run_qemu = b.step("run_qemu_" ++ sample_name, "Run sample app in qemu");
        run_qemu.dependOn(&qemu.step);

        const qemu_dbg = b.addSystemCommand(&[_][]const u8{
            "qemu-system-riscv32",
        });
        qemu_dbg.addArg("-machine");
        qemu_dbg.addArg("virt");
        qemu_dbg.addArg("-nographic");
        qemu_dbg.addArg("-s");
        qemu_dbg.addArg("-S");
        qemu_dbg.addArg("-bios");
        qemu_dbg.addArg("./samples/" ++ sample_name ++ "/zig-out/bin/" ++ sample_name ++ ".bin");

        const run_qemu_dbg = b.step("run_qemu_dbg_" ++ sample_name, "Run sample app in qemu");
        run_qemu_dbg.dependOn(&qemu_dbg.step);
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const std = @import("std");
const CrossTarget = @import("std").zig.CrossTarget;
const Target = @import("std").Target;
const Feature = @import("std").Target.Cpu.Feature;

pub fn build(b: *std.Build) void {
    const features = Target.riscv.Feature;
    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    // disable all CPU extensions
    disabled_features.addFeature(@intFromEnum(features.a));
    disabled_features.addFeature(@intFromEnum(features.c));
    disabled_features.addFeature(@intFromEnum(features.d));
    disabled_features.addFeature(@intFromEnum(features.e));
    disabled_features.addFeature(@intFromEnum(features.f));
    // except multiply
    enabled_features.addFeature(@intFromEnum(features.m));

    const target = b.resolveTargetQuery(.{ .cpu_arch = Target.Cpu.Arch.riscv32, .os_tag = Target.Os.Tag.freestanding, .abi = Target.Abi.none, .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 }, .cpu_features_sub = disabled_features, .cpu_features_add = enabled_features });

    const exe = b.addExecutable(.{
        .name = "hello.elf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
        .strip = false,
        //.optimize = .Debug,
    });

    exe.setLinkerScriptPath(b.path("src/linker.ld"));

    const bin = b.addObjCopy(exe.getEmittedBin(), .{
        .format = .bin,
    });
    bin.step.dependOn(&exe.step);

    const copy_bin = b.addInstallBinFile(bin.getOutput(), "hello.bin");
    b.default_step.dependOn(&copy_bin.step);
    b.installArtifact(exe);

    const qemu_run = b.addSystemCommand(&[_][]const u8{
        "qemu-system-riscv32", "-machine", "virt",
        "-nographic",
    });
    qemu_run.addArg("-bios");
    qemu_run.addFileArg(exe.getEmittedBin());
    const run = b.step("run", "Simulate using QEMU");
    run.dependOn(&qemu_run.step);

    const qemu_gdb = b.addSystemCommand(&[_][]const u8{
        "qemu-system-riscv32", "-machine", "virt",
        "-nographic",
    });
    qemu_gdb.addArg("-s");
    qemu_gdb.addArg("-S");
    qemu_gdb.addArg("-bios");
    qemu_gdb.addFileArg(exe.getEmittedBin());

    const run_gdb = b.step("gdb", "Simulate using QEMU and gdb");
    run_gdb.dependOn(&qemu_gdb.step);
}

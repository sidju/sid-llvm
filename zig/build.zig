const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Allow overriding the LLVM 18 prefix via `zig build -Dllvm-prefix=/path`.
    // Defaults to /usr/lib/llvm-18 (the standard location on Debian/Ubuntu).
    // On macOS with Homebrew: zig build -Dllvm-prefix=$(brew --prefix llvm@18)
    const prefix = b.option(
        []const u8,
        "llvm-prefix",
        "Path to the LLVM 18 installation prefix (default: /usr/lib/llvm-18)",
    ) orelse "/usr/lib/llvm-18";

    const include_path = b.pathJoin(&.{ prefix, "include" });
    const lib_path = b.pathJoin(&.{ prefix, "lib" });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // libc is required: the LLVM shared library was built against glibc
        // and Zig's default allocator conflicts with it without libc linked.
        .link_libc = true,
    });

    // Wire up the LLVM 18 C headers and shared library.
    mod.addIncludePath(.{ .cwd_relative = include_path });
    mod.addLibraryPath(.{ .cwd_relative = lib_path });
    // Embed an RPATH so the binary finds libLLVM-18.so at runtime without
    // requiring LD_LIBRARY_PATH.
    mod.addRPath(.{ .cwd_relative = lib_path });
    mod.linkSystemLibrary("LLVM-18", .{});

    const exe = b.addExecutable(.{
        .name = "sid-llvm-zig",
        .root_module = mod,
    });
    b.installArtifact(exe);

    // `zig build run -- [args]` passes args through to the binary.
    const run = b.addRunArtifact(exe);
    if (b.args) |a| run.addArgs(a);
    const run_step = b.step("run", "Build and run (pass -- --emit-llvm or -- --out <file>)");
    run_step.dependOn(&run.step);

    const parser_test_mod = b.createModule(.{
        .root_source_file = b.path("src/parse/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const parser_tests = b.addTest(.{
        .root_module = parser_test_mod,
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);
    const test_step = b.step("test", "Run parser tests");
    test_step.dependOn(&run_parser_tests.step);
}

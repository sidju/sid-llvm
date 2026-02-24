const std = @import("std");
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});
const llvm_backend = @import("llvm_backend.zig");

pub fn main() void {
    var iter = std.process.args();
    _ = iter.skip(); // skip argv[0]

    var emit_llvm = false;
    // `out` must be [:0]const u8 (null-terminated) so that `out.ptr` is a
    // valid C string for printf and for the C LLVM API in llvm_backend.
    var out: [:0]const u8 = "out.o";

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--emit-llvm")) {
            emit_llvm = true;
        } else if (std.mem.eql(u8, arg, "--out") or std.mem.eql(u8, arg, "-o")) {
            // Iterator.next() returns ?[:0]const u8 on POSIX (argv entries are
            // null-terminated C strings wrapped in a sentinel slice).
            out = iter.next() orelse {
                _ = c.fputs("error: --out requires a path argument\n", c.stderr);
                c.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            _ = c.puts(
                \\Usage: sid-llvm-zig [options]
                \\
                \\Options:
                \\  --emit-llvm       Print LLVM IR to stdout
                \\  --out, -o <file>  Write object file (default: out.o)
                \\  --help, -h        Show this help
            );
            return;
        }
    }

    if (emit_llvm) {
        llvm_backend.compileDemoModuleAndPrintIR("sid_demo");
    } else {
        llvm_backend.compileDemoModuleAndEmitObject("sid_demo", out);
        _ = c.printf("Object file written to %s\n", out.ptr);
    }
}

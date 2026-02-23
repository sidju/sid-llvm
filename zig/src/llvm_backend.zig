/// LLVM back-end via the LLVM C API (llvm-c/Core.h, llvm-c/TargetMachine.h).
///
/// Builds the same demo module as the Rust/inkwell side:
///   add(i64, i64) -> i64   — returns the sum of its two arguments
///   main() -> i64          — returns add(40, 2)
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("llvm-c/Core.h");
    @cInclude("llvm-c/Target.h");
    @cInclude("llvm-c/TargetMachine.h");
});

/// Build the demo module, print its IR to stdout, then dispose everything.
pub fn compileDemoModuleAndPrintIR(module_name: [*:0]const u8) void {
    const ctx, const mod, const builder = buildDemoModule(module_name);
    defer c.LLVMContextDispose(ctx);
    defer c.LLVMDisposeModule(mod);
    defer c.LLVMDisposeBuilder(builder);

    const ir = c.LLVMPrintModuleToString(mod);
    defer c.LLVMDisposeMessage(ir);
    _ = c.printf("%s", ir);
}

/// Build the demo module and emit a native object file to `out_path`.
/// `out_path` must be null-terminated ([:0]const u8).
pub fn compileDemoModuleAndEmitObject(module_name: [*:0]const u8, out_path: [:0]const u8) void {
    // Initialise all built-in targets so LLVMGetTargetFromTriple succeeds.
    c.LLVMInitializeAllTargetInfos();
    c.LLVMInitializeAllTargets();
    c.LLVMInitializeAllTargetMCs();
    c.LLVMInitializeAllAsmPrinters();

    const ctx, const mod, const builder = buildDemoModule(module_name);
    defer c.LLVMContextDispose(ctx);
    defer c.LLVMDisposeModule(mod);
    defer c.LLVMDisposeBuilder(builder);

    // Resolve host target triple, CPU name, and CPU feature string.
    const triple = c.LLVMGetDefaultTargetTriple();
    defer c.LLVMDisposeMessage(triple);
    const cpu = c.LLVMGetHostCPUName();
    defer c.LLVMDisposeMessage(cpu);
    const features = c.LLVMGetHostCPUFeatures();
    defer c.LLVMDisposeMessage(features);

    var target: c.LLVMTargetRef = null;
    var target_err: [*c]u8 = null;
    if (c.LLVMGetTargetFromTriple(triple, &target, &target_err) != 0) {
        _ = c.fprintf(c.stderr, "error: LLVMGetTargetFromTriple: %s\n", target_err);
        c.LLVMDisposeMessage(target_err);
        c.exit(1);
    }

    // PIC + default optimisation level, same as the Rust side.
    const machine = c.LLVMCreateTargetMachine(
        target,
        triple,
        cpu,
        features,
        c.LLVMCodeGenLevelDefault,
        c.LLVMRelocPIC,
        c.LLVMCodeModelDefault,
    );
    defer c.LLVMDisposeTargetMachine(machine);

    // Stamp the module with the target triple and data layout.
    c.LLVMSetTarget(mod, triple);
    const data_layout = c.LLVMCreateTargetDataLayout(machine);
    defer c.LLVMDisposeTargetData(data_layout);
    c.LLVMSetModuleDataLayout(mod, data_layout);

    var emit_err: [*c]u8 = null;
    if (c.LLVMTargetMachineEmitToFile(
        machine,
        mod,
        out_path.ptr,
        c.LLVMObjectFile,
        &emit_err,
    ) != 0) {
        _ = c.fprintf(c.stderr, "error: LLVMTargetMachineEmitToFile: %s\n", emit_err);
        c.LLVMDisposeMessage(emit_err);
        c.exit(1);
    }
}

/// Create the LLVM context, module, and builder, then populate the IR.
/// The caller owns all three returned values and must dispose of them.
fn buildDemoModule(
    module_name: [*:0]const u8,
) struct { c.LLVMContextRef, c.LLVMModuleRef, c.LLVMBuilderRef } {
    const ctx = c.LLVMContextCreate();
    const mod = c.LLVMModuleCreateWithNameInContext(module_name, ctx);
    const builder = c.LLVMCreateBuilderInContext(ctx);

    const i64t = c.LLVMInt64TypeInContext(ctx);

    // --- define add(i64, i64) -> i64 ---
    var add_param_types = [2]c.LLVMTypeRef{ i64t, i64t };
    const add_fn_type = c.LLVMFunctionType(i64t, &add_param_types, 2, 0);
    const add_fn = c.LLVMAddFunction(mod, "add", add_fn_type);
    const add_entry = c.LLVMAppendBasicBlockInContext(ctx, add_fn, "entry");
    c.LLVMPositionBuilderAtEnd(builder, add_entry);
    const a = c.LLVMGetParam(add_fn, 0);
    const b = c.LLVMGetParam(add_fn, 1);
    const sum = c.LLVMBuildAdd(builder, a, b, "sum");
    _ = c.LLVMBuildRet(builder, sum);

    // --- define main() -> i64  (returns add(40, 2)) ---
    const main_fn_type = c.LLVMFunctionType(i64t, null, 0, 0);
    const main_fn = c.LLVMAddFunction(mod, "main", main_fn_type);
    const main_entry = c.LLVMAppendBasicBlockInContext(ctx, main_fn, "entry");
    c.LLVMPositionBuilderAtEnd(builder, main_entry);
    var call_args = [2]c.LLVMValueRef{
        c.LLVMConstInt(i64t, 40, 0),
        c.LLVMConstInt(i64t, 2, 0),
    };
    const result = c.LLVMBuildCall2(builder, add_fn_type, add_fn, &call_args, 2, "result");
    _ = c.LLVMBuildRet(builder, result);

    return .{ ctx, mod, builder };
}

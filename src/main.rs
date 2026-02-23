use clap::Parser;

mod llvm_backend;

#[derive(Parser)]
struct Args {
    /// Print LLVM IR to stdout instead of writing an object file
    #[arg(long)]
    emit_llvm: bool,

    /// Output object file path
    #[arg(short, long, default_value = "out.o")]
    out: String,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    let module = llvm_backend::compile_demo_module("sid_demo")?;

    if args.emit_llvm {
        println!("{}", module.print_to_string().to_string());
    } else {
        llvm_backend::emit_object_file(&module, &args.out)?;
        println!("Object file written to {}", args.out);
    }

    Ok(())
}

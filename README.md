# sid-llvm

A minimal Rust + LLVM (inkwell) project that demonstrates building an LLVM IR module and emitting a native object file.

## Prerequisites

- Rust toolchain (stable)
- LLVM 18 development libraries — `inkwell` links against LLVM 18 at **build time** via
  [`llvm-sys`](https://crates.io/crates/llvm-sys); there is no bundled/prebuilt option, so
  the libraries must be installed on the build machine.

### Installing LLVM 18 on Debian / Ubuntu

```sh
sudo apt-get install llvm-18-dev libpolly-18-dev
```

`llvm-18-dev` provides the LLVM 18 headers and static libraries.  
`libpolly-18-dev` provides the Polly loop-optimiser static library, which `llvm-sys` links
unconditionally when it is present in the LLVM installation.

### macOS (Homebrew)

```sh
brew install llvm@18
```

### Setting the LLVM prefix

If LLVM 18 is installed in a non-standard location (or the `llvm-config` on your `PATH` does
not point to version 18), set `LLVM_SYS_180_PREFIX` to the LLVM prefix before building:

```sh
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18   # adjust to your installation path
```

## Usage

Print LLVM IR to stdout:

```sh
cargo run -- --emit-llvm
```

Compile to an object file:

```sh
cargo run -- --out out.o
```

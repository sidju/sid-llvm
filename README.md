# sid-llvm

Boilerplate for driving LLVM programmatically to build IR and emit native object
files in Rust using [inkwell](https://github.com/TheDan64/inkwell) (safe wrapper around `llvm-sys`).

The demo defines two functions and emits the following IR:

```llvm
define i64 @add(i64 %0, i64 %1) { … }   ; returns %0 + %1
define i64 @main() { … }                 ; returns add(40, 2)
```

---

## Prerequisites

LLVM 18 development libraries must be installed on the build machine.
The Rust build does not bundle LLVM.

### Nix (recommended)

This repo includes a `flake.nix` dev shell with LLVM 18, Rust tooling, and `just`:

```sh
nix develop
```

Inside the shell, `cargo` works directly (the shell exports `LLVM_SYS_180_PREFIX`).

### Debian / Ubuntu

```sh
sudo apt-get install llvm-18-dev libpolly-18-dev
```

`llvm-18-dev` provides the LLVM 18 headers and libraries.  
`libpolly-18-dev` is also required because `llvm-sys` links Polly unconditionally
when it is present in the LLVM installation.

### macOS (Homebrew)

```sh
brew install llvm@18
```

---

## Usage

### Setting the LLVM prefix

If `llvm-config` on your `PATH` does not point to version 18, set
`LLVM_SYS_180_PREFIX` before building:

```sh
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18   # adjust as needed
```

### Running

```sh
cargo run -- --emit-llvm          # print LLVM IR to stdout
cargo run -- --out out.o          # write a native object file
```


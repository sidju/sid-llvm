# sid-llvm

Boilerplate for driving LLVM programmatically to build IR and emit native object
files, implemented in two languages side-by-side:

| Directory | Language | LLVM binding |
|-----------|----------|--------------|
| *(root)*  | Rust     | [inkwell](https://github.com/TheDan64/inkwell) (safe wrapper around `llvm-sys`) |
| `zig/`    | Zig      | LLVM C API directly via `@cImport` |

Both demos define the same two functions and emit identical IR:

```llvm
define i64 @add(i64 %0, i64 %1) { … }   ; returns %0 + %1
define i64 @main() { … }                 ; returns add(40, 2)
```

---

## Prerequisites

LLVM 18 development libraries must be installed on the build machine.
Neither the Rust nor the Zig build bundles LLVM.

### Nix (recommended)

This repo includes a `flake.nix` dev shell with LLVM 18, Rust tooling, Zig,
`just`, and `zig-zlint` (when available in nixpkgs):

```sh
nix develop
```

Inside the shell:

- Rust can use `cargo` directly (the shell exports `LLVM_SYS_180_PREFIX`)
- Zig should use the provided prefix:

```sh
cd zig
zig build -Dllvm-prefix="$ZIG_LLVM_PREFIX" run -- --emit-llvm
zig build test
```

### Debian / Ubuntu

```sh
sudo apt-get install llvm-18-dev libpolly-18-dev
```

`llvm-18-dev` provides the LLVM 18 headers and libraries.  
`libpolly-18-dev` is also required because `llvm-sys` (used by the Rust side)
links Polly unconditionally when it is present in the LLVM installation.

### macOS (Homebrew)

```sh
brew install llvm@18
```

---

## Rust (`/`)

### Setting the LLVM prefix

If `llvm-config` on your `PATH` does not point to version 18, set
`LLVM_SYS_180_PREFIX` before building:

```sh
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18   # adjust as needed
```

### Usage

```sh
cargo run -- --emit-llvm          # print LLVM IR to stdout
cargo run -- --out out.o          # write a native object file
```

---

## Zig (`zig/`)

Requires Zig ≥ 0.16.  The build system uses the LLVM C API directly via
`@cImport`.

### Setting the LLVM prefix

Pass the prefix as a build option (defaults to `/usr/lib/llvm-18`):

```sh
zig build -Dllvm-prefix=/usr/lib/llvm-18          # Debian/Ubuntu default
zig build -Dllvm-prefix=$(brew --prefix llvm@18)  # macOS Homebrew
```

### Usage

```sh
cd zig
zig build run -- --emit-llvm      # print LLVM IR to stdout
zig build run -- --out out.o      # write a native object file
zig build test                    # run parser tests
```

If you use [`just`](https://github.com/casey/just), common Zig commands are also
available via `zig/justfile` (e.g. `just test`, `just emit-llvm`), and they
automatically pass `-Dllvm-prefix` using `ZIG_LLVM_PREFIX` (falling back to
`/usr/lib/llvm-18`).

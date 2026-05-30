# gawk

Standalone build of [GNU awk](https://www.gnu.org/software/gawk/) (Gawk), the GNU implementation of the AWK programming language.

[![CI](https://github.com/unpins/gawk/actions/workflows/gawk.yml/badge.svg)](https://github.com/unpins/gawk/actions)
![Linux](https://img.shields.io/badge/Linux-%E2%9C%93-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-%E2%9C%93-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-%E2%9C%93-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Usage

The package ships one executable, `gawk`. `unpin gawk` materializes an `awk` shim next to it; gawk doesn't switch behaviour on argv[0], so both names invoke the same binary.

```bash
gawk 'BEGIN { print "hello world" }'
awk -F: '{ print $1 }' /etc/passwd
gawk 'NR > 1 { sum += $3 } END { print sum }' data.csv
```

### Bundled scope

To keep the single-binary contract, this build:

- **disables dynamic extensions** (`@load "filefuncs"`, `@load "readdir"`, etc.). These are upstream's `.so`/`.dll` plugin modules that require `dlopen`/`LoadLibrary` — incompatible with statically-linked single-file releases. If you depend on extensions, build gawk from source or use your distribution's package.
- **omits the awklib helper scripts** (`passwd.awk`, `group.awk`, `ftrans.awk`, …) and the `grcat`/`pwcat` helpers under `libexec/awk/`. These are rarely used and would need a separate companion file.

The core AWK language (POSIX + the GNU extensions: `gensub`, multidimensional arrays, `length(array)`, etc.) is fully functional.

## Installation

Install with [unpin](https://github.com/unpins/unpin):

```bash
unpin gawk
```

Or run without installing:

```bash
unpin run gawk
```

## Build locally

```bash
nix build github:unpins/gawk
./result/bin/gawk --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Man pages

`gawk.1` (and its `awk` alias) plus `pm-gawk.1` (the persistent-memory feature) are embedded in the binary — read with `unpin man gawk`. `gawkbug.1` is excluded; the `gawkbug` script isn't shipped.

## Manual download

The [Releases](https://github.com/unpins/gawk/releases) page has standalone binaries for manual download.

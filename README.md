# gawk

[GNU awk](https://www.gnu.org/software/gawk/) (Gawk), the GNU implementation of the AWK programming language. A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/gawk/actions/workflows/gawk.yml/badge.svg)](https://github.com/unpins/gawk/actions)
![Linux](https://img.shields.io/badge/Linux-%E2%9C%93-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-%E2%9C%93-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-%E2%9C%93-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install gawk`.

## Usage

Run the `gawk` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin gawk '{print $1}' file
```

To install it onto your PATH:

```bash
unpin install gawk
```

`unpin install gawk` also creates an `awk` command.

### What is not included

- **Loadable extensions** (`@load "filefuncs"`, `@load "readdir"`, …) are not
  available. If you depend on them, use your distribution's gawk.
- **The awklib helper scripts** (`passwd.awk`, `group.awk`, `ftrans.awk`, …) and
  the `grcat`/`pwcat` helpers are not included.

The AWK language itself — POSIX plus the GNU extensions (`gensub`,
multidimensional arrays, `length(array)`, …) — is complete.

## Man pages

`gawk.1` (and its `awk` alias) plus `pm-gawk.1` (the persistent-memory feature) are embedded in the binary — read with `unpin man gawk`. `gawkbug.1` is excluded; the `gawkbug` script isn't shipped.

## Build locally

```bash
nix build github:unpins/gawk
./result/bin/gawk --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/gawk/releases) page has standalone binaries for manual download.

## Build notes

- **Aliases:** `unpin install gawk` also creates `awk`.
- **Windows** uses [Cosmopolitan](https://justine.lol/cosmopolitan/), not mingw: gawk's Windows support lives in a separate `pc/` port (its own `popen`, sockets and header forwards) that the ordinary configure path does not wire in, so a mingw build would mean maintaining a second one.
- **Line editing** in the `--debug` prompt is on for Linux and macOS (readline) and off on Windows, where cosmo ships no readline.
- **Not shipped:** `gawkbug` (a shell script for filing bug reports) and the loadable extensions, both outside the single-binary model. `pm-gawk` is not a separate program — it is gawk's persistent-memory mode, and its page is embedded.
- **Tests:** gawk's `make check` is not run; it shells out to `locale`/`more` and expects a UTF-8 locale, none of which the build sandbox has.

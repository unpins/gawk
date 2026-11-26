# Changelog

## [Unreleased]

### Added

- Line editing and history in the `--debug` prompt on Windows.
- The extensions that come with gawk work: `@load "filefuncs"`,
  `@load "readdir"`, `-l time` and the rest load from the binary itself.
  `fork` is not available on Windows.
- gawk's library of awk functions is built in: `@include "getopt"`,
  `-i join`, `-i inplace` and the rest work with nothing on disk, also when
  `AWKPATH` is set.

### Changed

- Windows: built with gawk's own MinGW port instead of Cosmopolitan.

## [5.4.1-1] - 2026-09-26

- Updated to gawk 5.4.1.

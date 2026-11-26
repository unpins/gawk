{
  description = "GNU awk as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # pkgsStatic.gawk ships bin/gawk plus libexec/awk/{grcat,pwcat} and the
  # share/awk library scripts. The scripts ride in the binary (./awklib.nix),
  # minus passwd/group/ns_passwd, which need grcat/pwcat; those two are not
  # shipped. Its C extensions (filefuncs, readdir, time, …) come out as static
  # archives gawk could never `@load`; here they are linked into the binary
  # instead (./static-ext.nix, patches/gawk-static-extensions.patch) and
  # `@load "name"` finds them there.
  # `awk` is an embedded alias (`unpin/aliases`); gawk doesn't switch behaviour
  # on argv[0], so both names invoke the same binary.
  #
  # Windows builds upstream's own MinGW port (`pc/`, ./mingw.nix).
  outputs = { self, unpins-lib }:
    let awklib = import ./awklib.nix { inherit unpins-lib; };
    in
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "gawk";

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      engine = "unpin-llvm";
      multicall = {
        programs = [{ name = "gawk"; aliases = [ "awk" ]; }];
        windows = true;
        # gawk bakes its own base $out into the default AWKPATH/AWKLIBPATH and
        # the locale dir. None of those directories exist even in the base (it
        # installs no `lib/gawk` and no `share/awk`), so the paths are dead — but
        # Nix still counts them as runtime refs and drags the base build, and
        # through its compiler wrapper the whole toolchain.
        removeReferences = [ "gawk-static" ];
        runtimeDataRoot = awklib.tree;
      };
      runtimeEmbed =
        let stage = pkgs: base: {
          runtimeStage = ''
            cp -a ${awklib.tree pkgs}/. "$__unpin_stage/"
            chmod -R u+w "$__unpin_stage"
          '';
        };
        in { native = stage; windows = stage; };
      windowsBuild = import ./mingw.nix { inherit unpins-lib; };
      smoke = [ "--version" ];
      smokePattern = "GNU Awk";
      build = pkgs:
        let
          readline = pkgs.pkgsStatic.readline;
          # Ship gawk WITH readline (debugger line-editing + history). nixpkgs'
          # `interactive = true` would also run the test suite, drop the `man`
          # output, and keep `gawkbug` — a bash-shebanged helper that is both a
          # second executable and a bash store-path ref. So keep the lean
          # `interactive = false` packaging and just turn readline on by hand.
          # readline's ncurses is leak-free via nix-lib's terminfo fix.
          prepared = (pkgs.pkgsStatic.gawk.override { interactive = false; }).overrideAttrs (old: {
            # Don't wire the native suite: gawk's `make check` shells out to
            # `locale`/`more` and expects a UTF-8 locale, none present in the
            # static-musl sandbox (`interactive = false` already keeps it off;
            # explicit here so the judgment is recorded).
            doCheck = false;
            buildInputs = (old.buildInputs or [ ]) ++ [ readline ];
            patches = (old.patches or [ ]) ++ [
              ./patches/gawk-static-extensions.patch
              ./patches/gawk-awklib-vfs.patch
            ];
            env = (old.env or { }) // {
              NIX_CFLAGS_COMPILE = toString [ (old.env.NIX_CFLAGS_COMPILE or "") awklib.cflag ];
            };
            configureFlags =
              (builtins.filter (f: f != "--without-readline") (old.configureFlags or [ ]))
              ++ [ "--with-readline=${readline.dev}" "CPPFLAGS=-DGAWK_STATIC_EXTENSIONS" ];
            # The C extensions (@load "filefuncs", …) are linked in: every
            # module upstream installs; testext is upstream's own test.
            preBuild = (old.preBuild or "") + import ./static-ext.nix {
              # extension/config.h, from the extension/ sub-configure
              cflags = "-Iextension";
              modules = {
                filefuncs.srcs = [ "extension/stack.c" "extension/gawkfts.c" ];
                fnmatch = { }; fork = { }; inplace = { }; intdiv = { }; ordchr = { };
                readdir = { }; readfile = { }; revoutput = { }; revtwoway = { };
                rwarray = { }; time = { };
              };
            } + awklib.vfsObjects false;
            # Every linked-in extension answers @load and registers its functions.
            doInstallCheck = with pkgs.pkgsStatic.stdenv; buildPlatform.canExecute hostPlatform;
            installCheckPhase = ''
              runHook preInstallCheck
              $out/bin/gawk '
                @load "filefuncs"; @load "fnmatch"; @load "fork"; @load "inplace"
                @load "intdiv"; @load "ordchr"; @load "readdir"; @load "readfile"
                @load "revoutput"; @load "revtwoway"; @load "rwarray"; @load "time"
                BEGIN {
                  n = split("stat fts fnmatch fork inplace::begin intdiv ord chr " \
                            "readfile writea reada gettimeofday sleep", f, " ")
                  for (i = 1; i <= n; i++)
                    if (!(f[i] in FUNCTAB)) { print "missing: " f[i]; bad = 1 }
                  exit bad
                }'
              runHook postInstallCheck
            '';
            # Embedded man set, here and in ./mingw.nix: gawk + its awk alias +
            # pm-gawk (the PMA persistent-memory feature that page documents,
            # built on 64-bit Linux and macOS only); gawkbug.1 goes because
            # gawkbug isn't shipped.
            postInstall = (old.postInstall or "") + ''
              rm -rf "$out/libexec" "$out/share/awk" "$out/lib/gawk"
              rmdir "$out/lib" 2>/dev/null || true
              # `awk → gawk` symlink shipped by upstream; the shipped binary
              # carries `awk` as an embedded alias (multicall.programs), so drop
              # the file artifact to keep the release tarball at one executable.
              rm -f "$out/bin/awk"
              # Drop gawkbug.1 — gawkbug isn't shipped. gawk is multi-output, so
              # the pages live in the `man` output (where withMan harvests),
              # not $out. Keeps the embedded set at gawk + awk + pm-gawk, the
              # same set ./mingw.nix installs for the .exe.
              rm -f "$man/share/man/man1/gawkbug.1"* "$out/share/man/man1/gawkbug.1"*
            '';
          });
        in
        prepared;
    };
}

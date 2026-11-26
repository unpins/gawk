# gawk for windows-x86_64 through upstream's own MinGW port (pc/, see
# README_d/README.pc): copy pc/* over the tree and `make mingw32-readline`.
# pc/config.h ships pre-generated, so there is no configure step. `gcc` in that
# target is put on PATH as the engine's mingw compiler.
{ unpins-lib }:
pkgs:
let
  cross = pkgs.pkgsCross.mingwW64;
  prefix = cross.stdenv.hostPlatform.config;
  mg = unpins-lib.lib.mingwStaticCross pkgs;
  readline = mg.readline.overrideAttrs (o: {
    # Same as bc: readline's mingw build leaves `PC` undefined unless asked.
    env = o.env // { CFLAGS = o.env.CFLAGS + " -DNEED_EXTERN_PC"; };
  });
  # The extensions upstream's pc/Makefile.ext builds, with its flags; fork has
  # no Windows port and testext is upstream's own test.
  extensions = {
    filefuncs.srcs = [ "extension/stack.c" ];
    fnmatch.flags = "-Imissing_d -DHAVE_FNMATCH_H";
    inplace = { }; intdiv = { }; ordchr = { }; readfile = { };
    readdir.flags = "-DHAVE_DIRENT_H";
    revoutput = { }; revtwoway = { }; rwarray = { };
    time.flags = "-DHAVE_GETSYSTEMTIMEASFILETIME";
  };
in
cross.stdenv.mkDerivation {
  pname = "gawk";
  inherit (pkgs.gawk) version src;

  outputs = [ "out" "man" ];
  buildInputs = [ readline ];
  strictDeps = true;
  enableParallelBuilding = true;
  dontConfigure = true;
  # A UCRT-configured mingw gcc predefines _UCRT, and pc/mbc32.h tests it before
  # any system header could; clang leaves it to _mingw.h, too late for that test.
  env.NIX_CFLAGS_COMPILE = "-D_UCRT -DGAWK_STATIC_EXTENSIONS";
  # The target links -lreadline alone (a DLL carries its own deps); the static
  # archive needs readline's termcap after it.
  env.NIX_LDFLAGS = "-ltermcap";

  patches = [
    ./patches/mingw-popen.patch
    ./patches/mingw-utf8-manifest.patch
    ./patches/gawk-static-extensions.patch
  ];

  postPatch = ''
    find pc -maxdepth 1 -type f ! -name 'ChangeLog*' -exec cp {} . \;
  '';

  preBuild = import ./static-ext.nix {
    cflags = "-D__USE_MINGW_ANSI_STDIO";
    modules = extensions;
  };

  buildPhase = ''
    runHook preBuild
    # mingw32-readline passes its own CF/LF2 down, so the objects ride in here.
    export NIX_LDFLAGS="$NIX_LDFLAGS $GAWK_STATIC_EXT_OBJS"
    mkdir -p .cc && ln -s "$(command -v ${prefix}-gcc)" .cc/gcc
    # VPATH: pc/Makefile spells it for a Windows-hosted make (`;`-separated).
    PATH="$PWD/.cc:$PATH" make -j$NIX_BUILD_CORES mingw32-readline \
      VPATH=.:./support:./support/malloc WINDRES=${prefix}-windres
    runHook postBuild
  '';

  # Embedded man set as on the other targets: gawk, its awk alias (a link, as
  # upstream's install makes it), pm-gawk and the extensions' pages; gawkbug
  # isn't shipped.
  installPhase = ''
    runHook preInstall
    install -Dm755 gawk.exe $out/bin/gawk.exe
    install -Dm644 -t $man/share/man/man1 doc/gawk.1 doc/pm-gawk.1
    ln -s gawk.1 $man/share/man/man1/awk.1
    for m in ${toString (builtins.attrNames extensions)}; do
      install -Dm644 extension/$m.3am $man/share/man/man3/$m.3am
    done
    runHook postInstall
  '';

  passthru = { pname = "gawk"; inherit (pkgs.gawk) version; };
}

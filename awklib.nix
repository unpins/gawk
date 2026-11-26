# The awk libraries (`@include "getopt"`, `-i join`, inplace.awk) read out of
# the binary: patches/gawk-awklib-vfs.patch sends the AWKPATH search through
# unpin-vfs and ends every AWKPATH with the mount.
{ unpins-lib }:
rec {
  root = "/__unpins_awk__";
  # On Windows vfs.c matches this by strstr, so a drive-prefixed or
  # backslashed path still resolves.
  marker = "__unpins_awk__";
  # NIX_CFLAGS_COMPILE is split on blanks with no quote removal: the quotes
  # reach the compiler.
  cflag = "-DUNPIN_AWKLIB_DIR=\"${root}\"";

  # upstream's awklib/eg/lib/*.awk, what `make install` puts in share/awk.
  # Out: ns_passwd.awk (passwd/group are not installed either; they call
  # pwcat/grcat, which are not shipped).
  tree = pkgs: pkgs.buildPackages.runCommand "gawk-awklib" { } ''
    mkdir -p "$out" src
    tar -xf ${pkgs.gawk.src} -C src --strip-components=4 --wildcards '*/awklib/eg/lib/*.awk'
    cp src/*.awk "$out/"
    rm "$out/ns_passwd.awk"
    test -s "$out/getopt.awk" && test -s "$out/inplace.awk"
  '';

  # preBuild snippet, after ./static-ext.nix: compiles the VFS objects and adds
  # them to GAWK_STATIC_EXT_OBJS, which reaches gawk's link.
  vfsObjects = isWin: ''
    mkdir -p unpin-vfs
    cp ${unpins-lib.lib.vfsCore}/*.c ${unpins-lib.lib.vfsCore}/*.h unpin-vfs/
    MZ="-DMINIZ_USE_ZSTD -DMINIZ_NO_TIME -DMINIZ_NO_ARCHIVE_WRITING_APIS -DMINIZ_NO_ZLIB_APIS -DMINIZ_NO_ZLIB_COMPATIBLE_NAMES"
    ( cd unpin-vfs
      $CC -O2 -c vfs.c -DUNPIN_VFS_DIRS -DUNPIN_VFS_SELF ${
        if isWin then "-DUNPIN_VFS_WIN_MARKER='\"${marker}\"'" else "-DUNPIN_VFS_NOWRAP"} \
        -DUNPIN_VFS_ROOT='"${root}/"' $MZ -o vfs.o
      $CC -O2 -c miniz.c      -D_GNU_SOURCE -w $MZ -o miniz.o
      $CC -O2 -c unpin_zstd.c -D_GNU_SOURCE -w $MZ -DUNPIN_ZSTD_VENDORED -o unpin_zstd.o
    )
    for o in vfs miniz unpin_zstd; do
      GAWK_STATIC_EXT_OBJS="$GAWK_STATIC_EXT_OBJS $PWD/unpin-vfs/$o.o"
    done
    export GAWK_STATIC_EXT_OBJS
  '';
}

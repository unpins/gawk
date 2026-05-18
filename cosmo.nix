# gawk via cosmoStaticCross for Windows-x86_64 (mingw is impractical — gawk's
# unix-configure path on mingw misses pc/popen.c + pc/socket.c + several
# header forwards that the gawk pc/ port wires in, and replicating that in
# Nix would be a full secondary build).
#
# cosmocc gaps:
#   * extension/ subdir builds dynamic plugins (filefuncs.dll etc.). Useless
#     for the single-binary contract AND collides with cosmo's stdlib.h
#     declaration of BSD `index()` shadowed by `static int index = -1;` in
#     extension/stack.c. `--disable-extensions` skips the subbuild.
#   * cosmocc lacks <readline/readline.h>; configure picks `--without-readline`
#     fine.
#
# apelink -V 4 strips the polyglot down to PE32+ for the .exe deliverable.
{ unpins-lib }:
pkgs:
let
  cosmoPkgs = unpins-lib.lib.cosmoStaticCross pkgs;

  patched = cosmoPkgs.gawk.overrideAttrs (oa: {
    configureFlags = (oa.configureFlags or [ ]) ++ [ "--disable-extensions" ];

    postInstall = (oa.postInstall or "") + ''
      rm -rf "$out/libexec" "$out/share/awk" "$out/lib/gawk"
      rmdir "$out/lib" 2>/dev/null || true
      # Drop the awk → gawk symlink — withAliases re-embeds it
      rm -f $out/bin/awk
    '';
  });

  apelinked = unpins-lib.lib.cosmoApelink pkgs { binName = "gawk"; } patched;
in
unpins-lib.lib.withAliases cosmoPkgs
  {
    primary = "gawk.exe";
    aliases = [ "awk" ];
  }
  apelinked

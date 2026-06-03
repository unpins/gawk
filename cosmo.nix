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

    # cosmocc 4.0.2's libc exports the BSD `err()` (libcosmo.a(err.o)). gawk's
    # msg.c defines its own `err`, so the cosmo link fails with "multiple
    # definition of `err'". gawk references only its own `err` (linked first,
    # from msg.o), so let the linker keep that one. Windows-only; native/musl
    # don't pull cosmo libc. Carried on NIX_CFLAGS_LINK so it reaches only the
    # $CC-driven final link, never a direct `ld -r`.
    NIX_CFLAGS_LINK = (oa.NIX_CFLAGS_LINK or "") + " -Wl,--allow-multiple-definition";

    postInstall = (oa.postInstall or "") + ''
      rm -rf "$out/libexec" "$out/share/awk" "$out/lib/gawk"
      rmdir "$out/lib" 2>/dev/null || true
      # Drop the awk → gawk symlink — withAliases re-embeds it
      rm -f $out/bin/awk
      # Drop gawkbug.1 (gawkbug isn't shipped) so the .exe harvests exactly
      # gawk + awk + pm-gawk — the same curated set as native. gawk is
      # multi-output under cosmo too, so the page lives in the `man` output.
      rm -f "$man/share/man/man1/gawkbug.1"* "$out/share/man/man1/gawkbug.1"*
    '';
  });

in
# `gawk` → `gawk.exe` happens automatically via the cosmo cross
# stdenv's apelink setup hook.
unpins-lib.lib.withAliases cosmoPkgs
  {
    primary = "gawk.exe";
    aliases = [ "awk" ];
  }
  patched

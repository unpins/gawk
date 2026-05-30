{
  description = "Standalone build of GNU awk";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # pkgsStatic.gawk ships:
  #   bin/gawk       — the ELF, ~900 KB stripped
  #   bin/awk → gawk — symlink
  #   libexec/awk/{grcat,pwcat} — small helpers invoked by the awklib library
  #                               scripts in share/awk
  #   share/awk/*.awk — library scripts (passwd.awk, group.awk, ftrans.awk, …)
  #   lib/gawk/*.a    — extension modules (filefuncs, readdir, time, …) built
  #                     as static archives because pkgsStatic blocks shared
  #                     libs. They are dead weight: gawk can only `@load` a
  #                     shared module, never a .a.
  #
  # `--disable-extensions` skips the extension/ subbuild entirely. We then
  # drop libexec/ and share/awk so the published artifact is gawk-only.
  # `awk` is registered as an UNPIN_META alias; gawk doesn't switch behaviour
  # on argv[0], so both names invoke the same binary.
  #
  # Windows routed through Cosmopolitan (`windowsBuild = import ./cosmo.nix
  # …`) because mingw cross of gawk hits gnulib POSIX gaps similar to
  # bash/coreutils. Per-binary cosmo recipe inline in `./cosmo.nix`.
  outputs = { self, unpins-lib }:
    let
      # Curated man set embedded on every platform: gawk + its awk alias +
      # pm-gawk (the shipped binary has the PMA persistent-memory feature that
      # page documents). gawkbug.1 is dropped — we don't ship the gawkbug
      # script. The cosmo Windows cross has no man to harvest, so this same set
      # is grafted via `winManRoot`; the native build harvests its own
      # $out/share/man after the gawkbug.1 removal below — byte-identical.
      gawkMan =
        let
          p = unpins-lib.inputs.nixpkgs.legacyPackages.x86_64-linux;
          man = p.gawk.man or p.gawk;
        in
        p.runCommand "gawk-man" { } ''
          mkdir -p $out/share/man/man1
          cp ${man}/share/man/man1/gawk.1.gz ${man}/share/man/man1/pm-gawk.1.gz $out/share/man/man1/
          ln -s gawk.1.gz $out/share/man/man1/awk.1.gz
        '';
    in
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "gawk";
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };
      winManRoot = gawkMan;
      smoke = [ "--version" ];
      smokePattern = "GNU Awk";
      build = pkgs:
        let
          prepared = (pkgs.pkgsStatic.gawk.override { interactive = false; }).overrideAttrs (old: {
            configureFlags = (old.configureFlags or [ ]) ++ [ "--disable-extensions" ];
            postInstall = (old.postInstall or "") + ''
              rm -rf "$out/libexec" "$out/share/awk" "$out/lib/gawk"
              rmdir "$out/lib" 2>/dev/null || true
              # `awk → gawk` symlink shipped by upstream; lib.withAliases re-embeds
              # it via UNPIN_META, so drop the file artifact to keep the release
              # tarball at exactly one executable.
              rm -f "$out/bin/awk"
              # Drop gawkbug.1 — gawkbug isn't shipped. gawk is multi-output, so
              # the pages live in the `man` output (where withMan harvests),
              # not $out. Keeps the embedded set (gawk + awk + pm-gawk) matching
              # winManRoot above.
              rm -f "$man/share/man/man1/gawkbug.1"* "$out/share/man/man1/gawkbug.1"*
            '';
          });
        in
        unpins-lib.lib.withAliases pkgs
          {
            primary = "gawk";
            aliases = [ "awk" ];
          }
          prepared;
    };
}

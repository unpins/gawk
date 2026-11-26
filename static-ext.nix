# gawk's C extensions linked into the binary (patches/gawk-static-extensions.patch):
# writes static-ext.h, the table `@load` consults, compiles each module with
# its dl_load renamed, and hands the objects to gawk's link through
# GAWK_STATIC_EXT_OBJS. `modules`: name -> { srcs ? [ ]; flags ? ""; }, the
# extra sources and defines upstream's Makefile gives that module.
{ modules, cflags }:
let
  inherit (builtins) attrNames concatStringsSep;
  one = m: { srcs ? [ ], flags ? "" }: ''
    tok=$(sed -n 's/^dl_load_func(func_table, *\([a-z_]*\),.*/\1/p' extension/${m}.c)
    [ -n "$tok" ] || { echo "extension/${m}.c: no dl_load_func" >&2; exit 1; }
    echo "GAWK_STATIC_EXT(\"${m}\", $tok)" >> static-ext.h
    for c in extension/${m}.c ${concatStringsSep " " srcs}; do
      o=''${c%.c}.static.o
      $CC -O2 -DHAVE_CONFIG_H -DGAWK_STATIC_EXTENSIONS ${cflags} ${flags} -I. -c "$c" -o "$o"
      GAWK_STATIC_EXT_OBJS="$GAWK_STATIC_EXT_OBJS $PWD/$o"
    done
  '';
in
''
  : > static-ext.h
  GAWK_STATIC_EXT_OBJS=
  ${concatStringsSep "\n" (map (m: one m modules.${m}) (attrNames modules))}
  export GAWK_STATIC_EXT_OBJS
''

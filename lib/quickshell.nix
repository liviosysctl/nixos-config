{ pkgs, lib }:

let
  qt = pkgs.qt6;

  # nixpkgs builds quickshell against qtbase, qtdeclarative, qtwayland and
  # qtsvg only. Every other Qt module a shell imports has to be put on the
  # search paths by hand.
  #
  # Note the two *separate* paths. QML2_IMPORT_PATH makes `import QtMultimedia`
  # resolve; QT_PLUGIN_PATH is what lets QtMultimedia find its media backend
  # under lib/qt-6/plugins/multimedia. Setting only the first is why an mp4
  # background loads without error and still renders black.
  defaultQtModules = with qt; [
    qtdeclarative
    qtsvg
    qt5compat
    qtmultimedia
    # Formats qtbase does not carry, webp above all. The bar reads whatever
    # the wallpaper happens to be — for the picker's thumbnails and for the
    # palette it derives from it — and without this a .webp wallpaper loads
    # as nothing at all: a blank thumbnail, and a ColorQuantizer with no
    # colours to quantize. It contributes only plugins, so it is here for
    # QT_PLUGIN_PATH rather than for the QML import path.
    qtimageformats
  ];

  qmlPath = modules: lib.makeSearchPath "lib/qt-6/qml" modules;
  pluginPath = modules: lib.makeSearchPath "lib/qt-6/plugins" modules;

  # One launcher body shared by the packaged apps and the dev runner, so a
  # shell that works under `qs-dev` behaves the same after a rebuild.
  # `resolveRoot` is a bash snippet that must set `root`.
  mkRunner =
    {
      name,
      resolveRoot,
      qtModules,
      runtimeInputs,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.quickshell ] ++ runtimeInputs;
      text = ''
        ${resolveRoot}

        if [ ! -f "$root/shell.qml" ]; then
          echo "$0: no shell.qml in $root" >&2
          exit 1
        fi

        export QML2_IMPORT_PATH="${qmlPath qtModules}''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
        export QT_PLUGIN_PATH="${pluginPath qtModules}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

        # Icon lookup needs a theme *name*, and the session-wide qt6ct sets
        # none — QIcon::themeName() comes back empty, so every fromTheme()
        # misses and tray menus render holes where their icons should be.
        # gtk3 reads gtk-icon-theme-name, which modules/home/gtk.nix already
        # owns, so the shell and every GTK app agree on one source of truth.
        #
        # Overriding the platform theme costs nothing here: a shell draws its
        # own chrome in QML, so the icon theme is the only part of it that
        # ever gets used.
        export QT_QPA_PLATFORMTHEME=gtk3

        # A shell's own imports/ takes precedence, which is how shim modules
        # (SddmComponents, a Qt5-named QtGraphicalEffects, ...) override the
        # real ones.
        if [ -d "$root/imports" ]; then
          export QML2_IMPORT_PATH="$root/imports:$QML2_IMPORT_PATH"
        fi

        # Qt reads QML_IMPORT_PATH; QML2_IMPORT_PATH is the Qt5-era name that
        # most shells still set. Keep them identical to avoid surprises.
        export QML_IMPORT_PATH="$QML2_IMPORT_PATH"

        # Needed if the shell reads its own config files over XMLHttpRequest,
        # which is the usual way QML parses a theme.conf.
        export QML_XHR_ALLOW_FILE_READ=1

        exec quickshell -p "$root" "$@"
      '';
    };
in
{
  inherit defaultQtModules;

  # Copies ./qml/<name> into the store and installs `qs-<name>`.
  mkApp =
    {
      name,
      src,
      qtModules ? defaultQtModules,
      runtimeInputs ? [ ],
    }:
    mkRunner {
      name = "qs-${name}";
      resolveRoot = "root=${lib.escapeShellArg "${src}"}";
      inherit qtModules runtimeInputs;
    };

  # Reads from the working tree instead of the store, so editing QML only
  # needs a re-run rather than a rebuild.
  mkDevRunner =
    {
      devRoot,
      qtModules ? defaultQtModules,
      runtimeInputs ? [ ],
    }:
    mkRunner {
      name = "qs-dev";
      resolveRoot = ''
        if [ $# -lt 1 ]; then
          echo "usage: qs-dev <name> [quickshell args...]" >&2
          echo "  runs \$QML_SRC_ROOT/<name>/shell.qml (default ${devRoot})" >&2
          exit 2
        fi
        root="''${QML_SRC_ROOT:-${devRoot}}/$1"
        shift
      '';
      inherit qtModules runtimeInputs;
    };
}

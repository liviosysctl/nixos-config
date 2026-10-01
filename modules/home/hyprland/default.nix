{ lib, ... }:
{
  imports = [
    ./custom-config.nix
    ./animations.nix
    ./autostart.nix
    ./decorations.nix
    ./environment.nix
    ./general.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./input.nix
    ./keybinds.nix
    ./lockscreen.nix
    ./windowrules.nix
    ./wallpaper-slideshow.nix
    ./xwayland-primary.nix
  ];

  wayland.windowManager.hyprland = {
    systemd.enable = false;
    enable = true;
    configType = "lua";

    # Replaces the old `source = ~/.config/hypr/monitors.conf`.
    #
    # monitors.lua is owned by the shell's settings panel (qml/bar/settings),
    # which rewrites it whole on every Apply. Home Manager appends extraConfig
    # last, after every hl.*() call it generates, so anything loaded here wins
    # over monitors declared in Nix.
    #
    # nwg-displays used to own this and wrote monitors.conf alongside for its
    # own read-back. That second file is no longer seeded: two writers for one
    # setting is how they end up disagreeing. nwg-displays still runs, but it
    # and the panel will now overwrite each other rather than sharing state —
    # pick one.
    #
    # To move monitors into Nix instead: drop this block and the activation
    # below, then add `settings.monitor = [ { output = "DP-1"; ... } ];` —
    # hl.monitor() is emitted once per list element.
    extraConfig = ''
      local hypr_config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"

      -- dofile rather than require, and it matters: Hyprland reuses one Lua
      -- state across `hyprctl reload`, so require() finds monitors in
      -- package.loaded and returns without re-reading the file. Every reload
      -- after the first would silently keep the monitor layout from session
      -- start, however many times the settings panel had rewritten it since.
      -- dofile re-executes unconditionally. It also needs no package.path
      -- entry, which the require version was re-prepending on every reload.
      --
      -- pcall so a missing or malformed monitors.lua leaves a usable display
      -- rather than no output at all.
      local ok, err = pcall(dofile, hypr_config_dir .. "/monitors.lua")
      if not ok then
        hl.monitor({
          output = "",
          mode = "preferred",
          position = "auto",
          scale = "auto",
        })
        hl.notification.create({
          text = "monitors.lua not loaded, using preferred mode: " .. tostring(err),
          timeout = 5000,
        })
      end
    '';
  };

  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      allow_token_by_default = true
    }
  '';

  # Seed monitors.lua on first run so the require above has something to find.
  # Never overwritten: past first run the settings panel owns this file.
  home.activation.createMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HYPR_DIR="$HOME/.config/hypr"
    mkdir -p "$HYPR_DIR"

    if [ ! -f "$HYPR_DIR/monitors.lua" ]; then
      cat > "$HYPR_DIR/monitors.lua" << 'EOF'
    -- Owned by the quickshell settings panel — do not edit manually
    -- Open the bar's settings panel to configure your monitors
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
    EOF
    fi
  '';
}

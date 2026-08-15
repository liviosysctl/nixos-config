{ ... }:
{
  # Kept after the waybar module was removed. Its power-profiles-daemon module
  # was the original reason this was switched on, and the quickshell bar has no
  # equivalent widget yet — but this is what actually applies the profile, so
  # turning it off would change how the machine behaves rather than just what
  # is on screen.
  services.power-profiles-daemon.enable = true;
}

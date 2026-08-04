{ pkgs, ... }:
{
  # Stellt unter /lib64/ld-linux-x86-64.so.2 einen Stub-Loader bereit, damit
  # generisch gelinkte Linux-Binaries laufen, die NixOS' FHS-freies Layout
  # sonst nicht finden. Betrifft u. a. von Zed/npx nachgeladene Binaries wie
  # den Claude-Agent-SDK-Adapter (@anthropic-ai/claude-agent-sdk-linux-x64)
  # sowie von Extensions heruntergeladene Sprachserver.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc # libstdc++
      zlib
      openssl
      curl
      sqlite
      xz
    ];
  };
}

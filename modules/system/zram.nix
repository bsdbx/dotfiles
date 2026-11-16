# Compressed swap in RAM
# No disk swap (no hibernation by design).
{
  flake.modules.nixos.zram = {
    zramSwap = {
      enable = true;
      algorithm = "zstd";
    };
  };
}

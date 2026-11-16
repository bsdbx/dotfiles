# sudo-rs: memory-safe sudo, drop-in compatible, no sudo junk.
{
  flake.modules.nixos.sudo = {
    security.sudo.enable = false;
    security.sudo-rs = {
      enable = true;
      execWheelOnly = true;
      wheelNeedsPassword = true;
    };
  };
}

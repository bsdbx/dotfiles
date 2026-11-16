{ inputs, config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.hephaestus = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      nixos.hephaestus-disk
      nixos.hephaestus-hardware
      nixos.amd-cpu
      nixos.kernel-latest
      nixos.nvidia
      nixos.boot
      nixos.impermanence
      nixos.minimal
      nixos.zram
      nixos.nix
      nixos.locale
      nixos.secrets
      nixos.network
      nixos.sudo
      nixos.zsh
      nixos.bohdan
      nixos.vm

      {
        networking.hostName = "hephaestus";
        sops.defaultSopsFile = ../../../secrets/hephaestus.yaml;
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "26.11";
      }
    ];
  };
}

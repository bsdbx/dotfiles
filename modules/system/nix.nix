# Nix itself
{
  flake.modules.nixos.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Features add the unfree package names they need here (e.g. the NVIDIA module);
      # everything else unfree is rejected.
      options.unfree.allowed = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Names of unfree packages this host may install.";
      };

      config = {
        nix = {
          package = pkgs.nixVersions.latest;
          channel.enable = false;
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            allowed-users = [ "@wheel" ];
            trusted-users = [ "root" ];
            auto-optimise-store = true;
            use-xdg-base-directories = true;
            max-jobs = "auto";
            cores = 0;
          };
        };

        programs.nh = {
          enable = true;
          flake = "/home/bohdan/src/github.com/bsdbx/nixos-config"; # ~cfg
          clean = {
            enable = true;
            extraArgs = "--keep 10 --keep-since 14d";
          };
        };

        nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) config.unfree.allowed;
      };
    };
}

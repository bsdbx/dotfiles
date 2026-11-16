{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
in
{
  flake.modules.nixos.bohdan =
    { config, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      sops.secrets.bohdan-password.neededForUsers = true;

      users = {
        mutableUsers = false;
        users.root.hashedPassword = "!";
        users.bohdan = {
          isNormalUser = true;
          uid = 1000;
          description = "Bohdan";
          extraGroups = [ "wheel" ];
          hashedPasswordFile = config.sops.secrets.bohdan-password.path;
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.bohdan.imports = [ hm.bohdan ];
      };
    };

  flake.modules.homeManager.bohdan = {
    imports = with hm; [
      zsh
      history
      completion
      atuin
      vi-mode
      prompt
    ];

    home.stateVersion = "26.11";
    xdg.enable = true;
  };
}

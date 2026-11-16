{
  description = "Dendritic NixOS configuration (hosts: hephaestus)";

  inputs = {
    # Unstable repo
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Dendritic pattern
    import-tree.url = "github:vic/import-tree";

    # Disk parititioning and formatting
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Files that survive a reboot
    preservation.url = "github:nix-community/preservation";

    # Secret enctypt/decrypt
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SOURCE ONLY: secret-detection filter rules for atuin.
    gitleaks = {
      url = "github:gitleaks/gitleaks";
      flake = false;
    };
  };

  outputs = inputs:
     inputs.flake-parts.lib.mkFlake
        { inherit inputs; }
        (inputs.import-tree ./modules);
}

{ inputs, ... }:
{
  flake.modules.nixos.secrets = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      age.keyFile = "/persist/var/lib/sops-nix/key.txt";
      age.sshKeyPaths = [ ];
      gnupg.sshKeyPaths = [ ];
    };
  };
}

{
  flake.modules.nixos.vm =
    { config, lib, ... }:
    let
      ramMounts = lib.mapAttrs (_: fs: { inherit (fs) device fsType options; }) (
        lib.filterAttrs (path: fs: fs.fsType == "tmpfs" && path != "/") config.fileSystems
      );
    in
    {
      virtualisation.vmVariant = {
        disko.enableConfig = false;

        sops.defaultSopsFile = lib.mkForce ../../secrets/vm.yaml;
        sops.age.keyFile = lib.mkForce "/mnt/vm-age/key.txt";
        virtualisation.sharedDirectories.vm-age = {
          source = ''"''${VM_AGE_DIR:?start the VM with nix run .#vm}"'';
          target = "/mnt/vm-age";
        };

        virtualisation = {
          diskImage = null;

          cores = 8;
          memorySize = 8192;
          graphics = false;

          emptyDiskImages = [
            {
              size = 16384;
              driveConfig.deviceExtraOpts.serial = "persist";
            }
            {
              size = 32768;
              driveConfig.deviceExtraOpts.serial = "home";
            }
          ];

          fileSystems = ramMounts // {
            "/".options = [ "size=4G" ];
            "/persist" = {
              device = "/dev/disk/by-id/virtio-persist";
              fsType = "ext4";
              autoFormat = true;
              neededForBoot = true;
            };
            "/home" = {
              device = "/dev/disk/by-id/virtio-home";
              fsType = "ext4";
              autoFormat = true;
            };
          };
        };
      };
    };
}

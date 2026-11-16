# Samsung 970 EVO 1TB: ESP + LUKS2 (everything else) → btrfs subvolumes. Root is tmpfs.
# This file should not be copied, consider tailoring for specific hardware
{ inputs, ... }:
let
  # btrfs applies compress=… filesystem-wide; noatime is per mount. Same set everywhere.
  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  flake.modules.nixos.hephaestus-disk = {
    imports = [ inputs.disko.nixosModules.disko ];

    disko.devices = {
      disk.nvme = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS1NA69110T";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                # No keyFile/passwordFile: disko asks for the passphrase interactively.
                # No bypassWorkqueues: on this drive the inline (no-workqueue) path capped
                # sequential reads at 1.0 GB/s; dm-crypt's parallel workqueues reach the
                settings.allowDiscards = true;
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "-f"
                    "-L"
                    "nixos"
                  ];
                  subvolumes = {
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = btrfsOpts;
                    };
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = btrfsOpts;
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = btrfsOpts;
                    };
                    "@snapshots" = {
                      mountpoint = "/snapshots";
                      mountOptions = btrfsOpts;
                    };
                    "@vms" = {
                      mountpoint = "/var/lib/vms";
                      mountOptions = btrfsOpts;
                    };
                  };
                };
              };
            };
          };
        };
      };

      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=4G"
          "defaults"
          "mode=755"
        ];
      };
    };

    # The cipher disko formatted with (LUKS2 default: aes-xts-plain64), including the
    # AES-NI driver: dm-crypt binds an implementation at unlock and keeps it, so without
    # aesni_intel in the initrd all disk I/O runs on software AES. sha256 is built in.
    boot.initrd.luks.cryptoModules = [
      "aesni_intel"
      "xts"
      "cryptd"
      "af_alg"
      "algif_skcipher"
    ];

    # btrfs mounts with discard=async (continuous TRIM); the weekly fstrim would repeat it.
    services.fstrim.enable = false;

    # preservation bind-mounts from /persist inside the initrd.
    fileSystems."/persist".neededForBoot = true;

    # VM disk images rewrite in place; copy-on-write would fragment them.
    # btrfs's nodatacow mount option is filesystem-wide, so set the per-directory
    # No_COW attribute instead (inherited by every file created inside).
    systemd.tmpfiles.rules = [ "h /var/lib/vms - - - - +C" ];
  };
}

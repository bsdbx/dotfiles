# Board-level drivers for hephaestus (MSI X570-A PRO), from nixos-generate-config.
# This file should not be copied, consider tailoring for specific hardware
{
  flake.modules.nixos.hephaestus-hardware =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Only what unlocking and mounting the root needs
      boot.initrd.availableKernelModules = [
        "nvme" # Samsung 970 EVO
        "xhci_pci" # USB controller
        # GSKY USB keyboard at the LUKS passphrase prompt.
        "usbhid"
        "hid_generic"
      ];
      # The Logitech receiver is used for the mouse; its drivers load after the initrd.

      # Only the firmware this board's drivers request:
      # r8169 → rtl_nic/, and the NVIDIA driver's GSP/ucode blobs for Ampere (ga10x) only, not Turing (tu10x).
      # CPU microcode comes from microcode-amd.
      hardware.enableRedistributableFirmware = false;
      hardware.firmware = lib.mkForce [
        (pkgs.runCommand "hephaestus-firmware" { } ''
          mkdir -p $out/lib/firmware
          cp -r ${pkgs.linux-firmware}/lib/firmware/rtl_nic $out/lib/firmware/
          fw=${config.hardware.nvidia.package.firmware}/lib/firmware
          for f in $fw/nvidia/*/*ga10x*; do
            install -Dm444 "$f" "$out/lib/firmware/''${f#$fw/}"
          done
        '')
      ];
    };
}

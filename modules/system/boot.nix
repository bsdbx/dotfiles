# systemd-boot + systemd initrd. later replaced with lanzaboote.
{
  flake.modules.nixos.boot = {
    boot = {
      loader = {
        timeout = 1; # menu shown for 1 s
        systemd-boot = {
          enable = true;
          editor = false; # no kernel-cmdline editing at the boot menu
          configurationLimit = 20;
          consoleMode = "max";
        };
        efi.canTouchEfiVariables = false;
      };

      initrd.systemd.enable = true; # required by preservation and later TPM2 unlock
      tmp.useTmpfs = true;
    };
  };
}

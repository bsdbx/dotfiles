# NVIDIA RTX 30-series and newer
{
  flake.modules.nixos.nvidia =
    { config, lib, ... }:
    {
      unfree.allowed = [ "nvidia-x11" ]; # the userspace half of the driver is proprietary

      # Also selects the driver for Wayland sessions, not only X11.
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.latest;
        open = true;
        modesetting.enable = true;
        powerManagement.enable = true; # keep VRAM contents across suspend
        nvidiaSettings = false; # X11-only GUI, useless under Wayland
        # VA-API (nvidia-vaapi-driver, pulls all of gst-plugins-bad) is enabled by the
        # browser feature, its only consumer.
        videoAcceleration = false;
      };

      hardware.graphics.enable = true;

      # The NixOS NVIDIA module enables acpid for the X11 driver; nothing reads it on
      # Wayland, and logind handles the power button.
      services.acpid.enable = lib.mkForce false;
    };
}

{
  flake.modules.nixos.locale =
    { lib, pkgs, ... }:
    {
      # Default for stationary hosts; a roaming host sets `time.timeZone = null` and enables automatic detection instead.
      time.timeZone = lib.mkDefault "Europe/Kyiv";

      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocales = [
          "uk_UA.UTF-8/UTF-8"
          "ru_RU.UTF-8/UTF-8"
        ];
      };

      console = {
        keyMap = "us";
        # TODO: automatic font setting depending on the screen resolution
        font = "ter-v32n"; # Terminus 32.
        packages = [ pkgs.terminus_font ];
        earlySetup = true; # already in the initrd, so the LUKS prompt uses the same font
      };
    };
}

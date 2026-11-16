# Everything NixOS installs by default that this system doesn't use.
{
  flake.modules.nixos.minimal =
    { modulesPath, ... }:
    {
      # /etc as an immutable overlay image + userborn for users instead of the
      # Perl activation scripts; drops perl/rsync/strace defaults, command-not-found,
      # nixos-generate-config; the build fails if anything Perl-based returns.
      imports = [ "${modulesPath}/profiles/perlless.nix" ];

      # Only offline docs
      documentation = {
        man.enable = true;
        doc.enable = false;
        info.enable = false;
        nixos.enable = false;
      };

      system.disableInstallerTools = true;
      services.logrotate.enable = false; # everything logs to the journal

      boot.bcache.enable = false; # SSD-caching-an-HDD layer, unused
      # Loading another kernel from a running one: unused, and a way around Secure Boot.
      boot.kexec.enable = false;
      xdg.sounds.enable = false; # desktop event-sound theme, unused

      # Initrd holds only what each host lists (disk, USB, keyboard, its cipher) instead of
      # NixOS's catch-all set (IDE/old SATA chipsets, USB 1.x, PS/2, SD, CD, vendor keyboards).
      boot.initrd.includeDefaultModules = false;

      # Crashes are still logged with a backtrace in the journal, but no memory dumps are
      # written to disk: they can contain passwords and keys from the crashed process.
      systemd.coredump.settings.Coredump.Storage = "none";
    };
}

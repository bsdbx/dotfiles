# Root is wiped on every boot (tmpfs). Only what is declared here, or by other features
# adding to `preservation.preserveAt."/persist"`, survives in /persist.
{ inputs, ... }:
{
  flake.modules.nixos.impermanence = {
    imports = [ inputs.preservation.nixosModules.preservation ];

    preservation = {
      enable = true;
      preserveAt."/persist" = {
        directories = [
          # uid/gid allocations; must exist before users are created
          {
            directory = "/var/lib/nixos";
            inInitrd = true;
          }
          "/var/log"
          "/var/lib/systemd/timers"
        ];
        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
          {
            file = "/var/lib/systemd/random-seed";
            how = "symlink";
            inInitrd = true;
            configureParent = true;
          }
        ];
      };
    };

    # With a bind-mounted machine-id this unit would fail and has nothing to commit.
    systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
  };
}

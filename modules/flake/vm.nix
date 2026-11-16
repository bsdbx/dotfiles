{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      vm = self.nixosConfigurations.hephaestus.config.system.build.vm;
      launcher = pkgs.writeShellApplication {
        name = "hephaestus-vm";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          state="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-vm"
          disks="$state/hephaestus"

          if [[ ''${1:-} == --reset ]]; then
            rm -rf "$disks"
            echo "VM disks deleted: this boot starts with empty /persist and /home."
          fi
          if [[ ! -s $state/age/key.txt ]]; then
            echo "No VM key at $state/age/key.txt (one-time setup: see .sops.yaml)." >&2
            exit 1
          fi

          mkdir -p "$disks"
          # Leftovers of this run: virtiofs sockets and the host<->VM exchange folder.
          trap 'rm -rf "$disks"/tmp.* "$disks"/xchg' EXIT
          echo "Quit with 'sudo poweroff' in the VM (Ctrl-A x = power cut: recent writes are lost)."
          # The console is a serial line: it can't tell the VM this terminal's size or type, so
          # systemd would assume 80x24 and vt220 (no colors). Pass both at boot (systemd's
          # tty kernel options); after resizing the window: `stty rows R cols C` in the VM.
          tty=""
          if size=$(stty size 2>/dev/null); then
            tty="systemd.tty.rows.ttyS0=''${size% *} systemd.tty.columns.ttyS0=''${size#* }"
          fi
          export QEMU_KERNEL_PARAMS="systemd.tty.term.ttyS0=xterm-256color $tty ''${QEMU_KERNEL_PARAMS:-}"
          # USE_TMPDIR: reuse $TMPDIR (the disk folder) instead of a new temp dir per run.
          USE_TMPDIR=1 TMPDIR=$disks VM_AGE_DIR=$state/age ${vm}/bin/run-hephaestus-vm
        '';
      };
    in
    {
      apps.vm = {
        type = "app";
        program = lib.getExe launcher;
        meta.description = "Boot hephaestus as a VM in this terminal (state kept between runs)";
      };
    };
}

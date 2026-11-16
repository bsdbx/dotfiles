{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      hm = self.nixosConfigurations.hephaestus.config.home-manager.users.bohdan;
      home = hm.home.homeDirectory;
      launcher = pkgs.writeShellApplication {
        name = "try-shell";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gnugrep
          gnused
        ];
        text = ''
          sb=$(mktemp -d)
          trap 'sleep 1; rm -rf "$sb"; echo "Test home removed."' EXIT

          # The generated dotfiles, with the real home path rewritten to the test home.
          cp -rL --no-preserve=mode ${hm.home-files}/. "$sb/"
          grep -rlZ ${home} "$sb" | xargs -0 -r sed -i "s|${home}|$sb|g"

          # Home Manager's session variables (XDG_*) are sourced from the store: copy them,
          # rewrite them, and point the dotfiles at the copy.
          grep -rhoE '/nix/store/[^"]*hm-session-vars\.sh/etc/profile\.d/hm-session-vars\.sh' "$sb" | sort -u |
          while read -r f; do
            cp "$f" "$sb/.hm-session-vars.sh"
            chmod u+w "$sb/.hm-session-vars.sh"
            sed -i "s|${home}|$sb|g" "$sb/.hm-session-vars.sh"
            grep -rlZ -- "$f" "$sb" | xargs -0 -r sed -i "s|$f|$sb/.hm-session-vars.sh|g"
          done

          ln -s "$HOME/src" "$sb/src"
          mkdir -m 700 "$sb/rt"
          cd "$sb"
          echo "Test shell: home is $sb (deleted on exit). Type 'exit' to leave."
          env -i HOME="$sb" USER="$USER" TERM="$TERM" LANG="''${LANG:-en_US.UTF-8}" \
            COLORTERM="''${COLORTERM:-}" NIX_PROFILES=${hm.home.path} \
            PATH=${hm.home.path}/bin:/usr/bin:/bin XDG_RUNTIME_DIR="$sb/rt" \
            ${lib.getExe hm.programs.zsh.package} -i || true
        '';
      };
    in
    {
      apps.try-shell = {
        type = "app";
        program = lib.getExe launcher;
        meta.description = "Run hephaestus' zsh config in a throwaway home";
      };
    };
}

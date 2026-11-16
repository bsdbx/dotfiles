{
  flake.modules.nixos.abbr.unfree.allowed = [ "zsh-abbr" ];

  flake.modules.homeManager.abbr =
    { config, lib, ... }:
    {
      home.packages = [ config.programs.zsh.zsh-abbr.package ];

      programs.zsh = {
        zsh-abbr = {
          enable = true;
          abbreviations = {
            g = "git";
            ga = "git add";
            gc = "git commit";
            gd = "git diff";
            gl = "git log";
            gs = "git status";
            gsw = "git switch";
            nb = "nix build";
            nd = "nix develop";
            nfc = "nix flake check";
            nfu = "nix flake update";
            nr = "nix run";
            ns = "nix shell";
          };
          globalAbbreviations = { };
        };

        localVariables = {
          ABBR_AUTOLOAD = 0;
          ABBR_DEBUG = 0;
          ABBR_DEFAULT_BINDINGS = 0;
          ABBR_DRY_RUN = 0;
          ABBR_EXPAND_AND_ACCEPT_PUSH_ABBREVIATED_LINE_TO_HISTORY = 0;
          ABBR_EXPAND_PUSH_ABBREVIATION_TO_HISTORY = 0;
          ABBR_EXPANSION_CURSOR_MARKER = "%";
          ABBR_EXPERIMENTAL_COMMAND_POSITION_REGULAR_ABBREVIATIONS = 0;
          ABBR_FORCE = 0;
          ABBR_GET_AVAILABLE_ABBREVIATION = 0;
          ABBR_LINE_CURSOR_MARKER = "%";
          ABBR_LOG_AVAILABLE_ABBREVIATION = 0;
          ABBR_LOG_AVAILABLE_ABBREVIATION_AFTER = 0;
          ABBR_QUIET = 0;
          ABBR_QUIETER = 0;
          ABBR_SET_EXPANSION_CURSOR = 0;
          ABBR_SET_LINE_CURSOR = 0;
          ABBR_USER_ABBREVIATIONS_FILE = "${config.xdg.configHome}/zsh-abbr/user-abbreviations";
        };

        initContent = lib.mkMerge [
          (lib.mkOrder 550 ''
            ABBR_TMPDIR="''${XDG_RUNTIME_DIR:-${config.xdg.cacheHome}}/zsh-abbr"
            typeset -ga ABBR_REGULAR_ABBREVIATION_SCALAR_PREFIXES=('sudo ')
            typeset -ga ABBR_REGULAR_ABBREVIATION_GLOB_PREFIXES=(' ')
            fpath+=(${config.programs.zsh.zsh-abbr.package}/share/zsh/zsh-abbr/completions)
          '')
          (lib.mkOrder 1460 ''
            autoload -Uz _abbr
            _abbr-accept() { CURSOR=$#BUFFER; zle abbr-expand-and-accept }
            zle -N _abbr-accept
            bindkey -M viins ' ' abbr-expand-and-insert
            bindkey -M viins '^@' magic-space
            bindkey -M viins '^M' _abbr-accept
            bindkey -M viins '^J' _abbr-accept
            bindkey -M vicmd '^M' _abbr-accept
            bindkey -M vicmd '^J' _abbr-accept
          '')
        ];
      };
    };
}

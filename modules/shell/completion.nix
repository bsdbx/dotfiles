{
  flake.modules.homeManager.completion =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      options = {
        ALWAYS_LAST_PROMPT = true;
        ALWAYS_TO_END = true;
        AUTO_LIST = true;
        AUTO_MENU = true;
        AUTO_NAME_DIRS = false;
        AUTO_PARAM_KEYS = true;
        AUTO_PARAM_SLASH = true;
        AUTO_REMOVE_SLASH = true;
        BASH_AUTO_LIST = false;
        COMPLETE_ALIASES = false;
        COMPLETE_IN_WORD = true;
        GLOB_COMPLETE = true;
        HASH_LIST_ALL = true;
        LIST_AMBIGUOUS = false;
        LIST_BEEP = false;
        LIST_PACKED = true;
        LIST_ROWS_FIRST = false;
        LIST_TYPES = true;
        MENU_COMPLETE = false;
        REC_EXACT = false;
      };
      cache = "${config.xdg.cacheHome}/zsh";
      lsColors = "di=01;34:ln=01;36:pi=33:so=01;35:bd=01;33:cd=01;33:ex=01;32:su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44";
      systemUsers = lib.attrNames (
        lib.filterAttrs (name: u: !u.isNormalUser && name != "root") osConfig.users.users
      );
    in
    {
      programs.zsh = {
        enableCompletion = true;
        setOptions = lib.mapAttrsToList (name: on: if on then name else "NO_${name}") options;
        completionInit = ''
          zmodload zsh/complist # the menu (menu selection) and colored lists

          # compinit: finds every completion function on fpath and records them in a dump file.
          # Scanning them (and checking the folders' ownership) costs ~12 ms per shell, so it's
          # done only when the fpath folders' contents change (a new generation: ~0.4 s, once);
          # otherwise the dump (compiled) loads in ~3 ms.
          autoload -Uz compinit
          () {
            local dir=${cache} key="''${fpath:A}" line=
            [[ -r $dir/compdump.key ]] && read -r line < $dir/compdump.key
            if [[ $line == "$key" && -s $dir/compdump ]]; then
              compinit -C -d $dir/compdump
            else
              mkdir -p $dir
              rm -f $dir/compdump $dir/compdump.zwc
              compinit -d $dir/compdump
              zcompile $dir/compdump
              print -r -- $key >| $dir/compdump.key
            fi
          }

          # What completes: the command's completion, then (if nothing matched) what's hidden.
          zstyle ':completion:*' completer _complete _ignored
          # Matching: lowercase letters match either case, uppercase only uppercase (vim's
          # smartcase); if nothing starts that way, anywhere in the name: `pin` → alpine.txt.
          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'm:{a-z}={A-Z} l:|=* r:|=*'
          # A folder that exists as typed is taken as is, not matched again: `src/n<Tab>`
          # completes inside src/, not inside every folder whose name contains "src".
          zstyle ':completion:*' accept-exact-dirs true
          # Hidden unless nothing else matches: shell-internal functions and variables
          # (_pr_render, _comps, __atuin_…), service accounts (in `~<Tab>`, chown, su lists).
          zstyle ':completion:*:(functions|parameters)' ignored-patterns '_*'
          zstyle ':completion:*:users' ignored-patterns ${lib.escapeShellArgs systemUsers}
          zstyle ':completion:*' rehash true # commands added by a rebuild complete without `rehash`
          # Slow lists (systemd units, kernel modules, Python modules) are kept between Tabs.
          zstyle ':completion:*' use-cache true
          zstyle ':completion:*' cache-path ${cache}/compcache

          # The menu: on the second Tab, or on the first if the list doesn't fit the screen (it
          # scrolls, instead of asking "do you wish to see all 1947 possibilities?" and printing
          # them all); then a gray "12/1947" under it.
          zstyle ':completion:*' menu select select=long-list
          zstyle ':completion:*' select-prompt '%F{8}%m%f'
          # Lists: matches grouped under a gray heading (file, command, alias, option…); files
          # colored as by `ls`; a red line when nothing matches.
          zstyle ':completion:*' group-name '''
          zstyle ':completion:*:descriptions' format '%F{8}%d%f'
          zstyle ':completion:*:warnings' format '%F{red}no match%f'
          zstyle ':completion:*:default' list-colors ''${(s.:.)LS_COLORS:-${lsColors}}

          # Keys (see the top of completion.nix).
          bindkey -M viins '^I' expand-or-complete # Tab: a whole $VAR or !! word expands first
          bindkey -M viins '^[[Z' reverse-menu-complete # Shift-Tab
          bindkey -M viins '^N' menu-complete '^P' reverse-menu-complete
          bindkey -M menuselect '^N' menu-complete '^P' reverse-menu-complete
          bindkey -M menuselect '^[[Z' reverse-menu-complete
          bindkey -M menuselect '^Y' accept-line # take the match (the command doesn't run)
          bindkey -M menuselect '^E' send-break # cancel: the line as it was before the menu
          # Esc: take the match and go to normal mode, as in vim (unbound, the menu would swallow
          # it: Esc starts the arrow keys' sequences there).
          bindkey -M menuselect '^[' vi-cmd-mode
        '';
      };
    };
}

{
  flake.modules.homeManager.vi-mode =
    { lib, ... }:
    let
      options = {
        VI = true;
        EMACS = false;
        BEEP = false;
        COMBINING_CHARS = true;
        OVERSTRIKE = false;
        SINGLE_LINE_ZLE = false;
        ZLE = true;
      };
    in
    {
      programs.zsh = {
        defaultKeymap = null;
        setOptions = lib.mapAttrsToList (name: on: if on then name else "NO_${name}") options;
        initContent = lib.mkOrder 1450 ''
          # Esc switches to normal mode after 10 ms (zsh's default: 400), the wait for keys
          # that start with Esc (arrows arrive within it). Nothing typed by hand waits on it.
          KEYTIMEOUT=1

          # --- Insert mode, as Neovim's: Backspace, Ctrl-W and Ctrl-U also delete what was
          # there before insert mode started (zsh's vi versions stop there, as old vi did);
          # Ctrl-W by vim's word rules; neither touches a register.
          _vi-ins-delete-word() { local end=$CURSOR; zle .vi-backward-word; BUFFER[CURSOR+1,end]= }
          _vi-ins-delete-line() { LBUFFER= }
          zle -N _vi-ins-delete-word
          zle -N _vi-ins-delete-line
          bindkey -M viins '^?' backward-delete-char '^H' backward-delete-char
          bindkey -M viins '^W' _vi-ins-delete-word '^U' _vi-ins-delete-line
          bindkey -M viins '^[[1;5D' vi-backward-word '^[[1;5C' vi-forward-word # Ctrl-←/→
          # Home, End, Delete, unbound in zsh's vi keymaps, in every form terminals send:
          # xterm-style (kitty, Ghostty), its keypad mode, and VT-style (Linux console, tmux).
          for k in '^[[H' '^[OH' '^[[1~' '^[[7~'; do
            bindkey -M viins $k beginning-of-line
            bindkey -M vicmd $k vi-beginning-of-line
          done
          for k in '^[[F' '^[OF' '^[[4~' '^[[8~'; do
            bindkey -M viins $k end-of-line
            bindkey -M vicmd $k vi-end-of-line
          done
          bindkey -M viins '^[[3~' delete-char
          bindkey -M vicmd '^[[3~' vi-delete-char

          # --- Normal mode
          bindkey -M vicmd Y vi-yank-eol # as Neovim: Y = y$ (vi: the whole line, as yy)
          # / and ? search history in atuin (atuin binds /); Ctrl-R stays vim's redo here.
          bindkey -M vicmd '?' atuin-search

          # --- Text objects vim has and zsh doesn't bind: i" a" i' a' i` a`, i( a( ib ab,
          # i[ a[, i{ a{ iB aB, i< a< (zsh's own widgets); iw aw iW aW are built in.
          autoload -Uz select-quoted select-bracketed
          zle -N select-quoted
          zle -N select-bracketed
          # a" a' a`: as vim, with the blanks after the quotes, or before them when there are none
          # after (zsh's own stops at the quote). The region's end is exclusive after an
          # operator, inclusive in visual mode (REGION_ACTIVE).
          _vi-select-quoted() {
            zle select-quoted || return
            [[ $KEYS[1] == a ]] || return 0
            local -i end=CURSOR+REGION_ACTIVE e=CURSOR+REGION_ACTIVE
            while [[ $BUFFER[e+1] == [[:blank:]] ]]; do (( e++ )); done
            if (( e > end )); then
              (( CURSOR = e - REGION_ACTIVE ))
            else
              while (( MARK > 0 )) && [[ $BUFFER[MARK] == [[:blank:]] ]]; do (( MARK-- )); done
            fi
          }
          zle -N _vi-select-quoted
          for km in viopp visual; do
            for q in "'" '"' '`'; do bindkey -M $km -- a$q _vi-select-quoted i$q select-quoted; done
            for b in '(' ')' b '[' ']' '{' '}' B '<' '>'; do
              bindkey -M $km -- a$b select-bracketed i$b select-bracketed
            done
          done

          # --- Surround (vim-surround): cs"' ds( ysiw" and S" in visual mode, zsh's widgets.
          # c d y become thin wrappers around zsh's own operators that note which one is
          # pending, so `s` after it is cs ds ys with no key timeout (zsh doesn't tell the widget
          # reading a motion which operator asked). Counts, registers, dd/cc/yy and `.` (repeats
          # changes and deletes, not yanks) are unchanged.
          typeset -g _vi_op
          _vi-change() { zle -f vichange; _vi_op=change; zle .vi-change; local s=$?; _vi_op=; return s }
          _vi-delete() { zle -f vichange; _vi_op=delete; zle .vi-delete; local s=$?; _vi_op=; return s }
          _vi-yank() { _vi_op=yank; zle .vi-yank; local s=$?; _vi_op=; return s }
          zle -N vi-change _vi-change
          zle -N vi-delete _vi-delete
          zle -N vi-yank _vi-yank
          autoload -Uz surround
          zle -N change-surround surround
          zle -N delete-surround surround
          zle -N add-surround surround
          # `s` cancels the operator and runs the surround command right after it, at top level
          # (inside an operator, the add's own motion read would break). Ctrl-X Ctrl-S c/d/y:
          # private keys for that hand-over only.
          _vi-surround() { [[ -n $_vi_op ]] && zle -U $'\C-x\C-s'$_vi_op[1]; return 1 }
          zle -N _vi-surround
          bindkey -M viopp s _vi-surround
          bindkey -M vicmd '^X^Sc' change-surround '^X^Sd' delete-surround '^X^Sy' add-surround
          bindkey -M visual S add-surround

          # --- vv: the command line in $EDITOR; saved and closed, it's back on the prompt (not
          # run). The first v is visual mode at once; v in visual mode opens the editor (vim's
          # "v again leaves visual mode" is Esc here). No key waits on a timeout.
          autoload -Uz edit-command-line
          zle -N edit-command-line
          _vi-visual-edit() { REGION_ACTIVE=0; zle edit-command-line }
          zle -N _vi-visual-edit
          bindkey -M visual v _vi-visual-edit
        '';
      };
    };
}

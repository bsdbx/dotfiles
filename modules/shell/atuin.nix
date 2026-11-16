# atuin: every command in a local SQLite database (exit code, duration, directory, session),
# searched with Ctrl-R. The only history on disk: zsh keeps just each terminal's commands in
# memory for ↑ (history.nix).
# Settings: the full list of atuin 18.21 (`atuin default-config`), each set explicitly.
{ inputs, lib, ... }:
let
  # Secret patterns: commands matching any of these are never stored.
  # Template: every detection rule of gitleaks (pinned flake input, updated with the lock),
  # minus rules that only match file paths. Plus credential shapes gitleaks doesn't know.
  gitleaksPatterns = map (rule: rule.regex) (
    lib.filter (rule: rule ? regex)
      (builtins.fromTOML (builtins.readFile "${inputs.gitleaks}/config/gitleaks.toml")).rules
  );
  ourPatterns = [
    "tskey-(auth|client|api|webhook)-[A-Za-z0-9-]{10,}" # Tailscale keys
    "(?i)private[_-]?key\\s*[=: ]\\s*[A-Za-z0-9+/]{42,43}=" # WireGuard private keys
  ];

  # atuin compiles all patterns into one regex set, limited to 10 MB. In its Rust engine
  # \w \d \s mean *all of Unicode*, and gitleaks repeats them ({0,50}), so the full list
  # compiles far past the limit and atuin then fails to load at all. Secrets are ASCII:
  # rewrite those classes to their ASCII ranges (inside [...] as ranges, outside as a
  # class). Same matches for tokens; the whole list then fits.
  asciify =
    pattern:
    let
      ascii = {
        w = "0-9A-Za-z_";
        d = "0-9";
        s = " \\t\\n\\r\\f\\v";
      };
      step =
        st: c:
        if st.esc then
          if ascii ? ${c} then
            st
            // {
              esc = false;
              prev = c;
              out = st.out + (if st.cls then ascii.${c} else "[${ascii.${c}}]");
            }
          else
            st
            // {
              esc = false;
              prev = c;
              out = st.out + "\\" + c;
            }
        else if c == "\\" then
          st // { esc = true; }
        else
          st
          // {
            prev = c;
            out = st.out + c;
            cls =
              if c == "[" && !st.cls then
                true
              else if c == "]" && st.cls && st.prev != "[" && st.prev != "^" then
                false
              else
                st.cls;
          };
    in
    (lib.foldl' step {
      out = "";
      cls = false;
      esc = false;
      prev = "";
    } (lib.stringToCharacters pattern)).out;

  secretPatterns = map asciify (gitleaksPatterns ++ ourPatterns);
in
{
  flake.modules.homeManager.atuin =
    { config, pkgs, ... }:
    let
      # `atuin init zsh` loads the settings (compiling the filter, ~60 ms) just to print a
      # fixed script that doesn't depend on them. Generate it once at build time instead
      # of `eval "$(atuin init zsh)"` in every new shell.
      atuinInit = pkgs.runCommand "atuin-init.zsh" { } ''
        export HOME=$TMPDIR ATUIN_CONFIG_DIR=$TMPDIR/atuin
        mkdir -p $ATUIN_CONFIG_DIR # atuin writes a default config on first run
        ${lib.getExe config.programs.atuin.package} init zsh ${lib.escapeShellArgs config.programs.atuin.flags} > $out
      '';
    in
    {
      # Asynchronous recording. atuin's own preexec runs `history start` synchronously
      # (it needs the entry id) and recompiles the secret filter each time: ~60 ms before
      # every command. These replacements keep its behavior (filter, start time, exit code,
      # duration, OSC 133 marks) but run `start` in the background, hand the id over via a
      # private file in $XDG_RUNTIME_DIR, and let `end` wait for it, also in the background.
      # They override atuin internals, so the flake check fails if atuin renames them.
      programs.zsh.initContent = lib.mkMerge [
        (lib.mkOrder 1400 "source ${atuinInit}")
        (lib.mkAfter ''
          typeset -gi _atuin_seq=0
          typeset -g _atuin_idfile=""
          _atuin_preexec() {
            __atuin_osc133_command_executed
            __atuin_preexec_time=''${EPOCHREALTIME-}
            _atuin_idfile="''${XDG_RUNTIME_DIR:-/tmp}/atuin-id.$$.$(( ++_atuin_seq ))"
            ( ATUIN_SHELL=zsh atuin history start --hook -- "$1" >| "$_atuin_idfile.tmp" &&
                mv -f "$_atuin_idfile.tmp" "$_atuin_idfile" ) 2>/dev/null &!
          }
          _atuin_precmd() {
            local EXIT="$?" __atuin_precmd_time=''${EPOCHREALTIME-}
            __atuin_osc133_wrap_prompt
            [[ -z $_atuin_idfile ]] && return
            local duration=""
            if [[ -n $__atuin_preexec_time && -n $__atuin_precmd_time ]]; then
              printf -v duration %.0f $(( (__atuin_precmd_time - __atuin_preexec_time) * 1000000000 ))
            fi
            __atuin_osc133_command_finished "$EXIT"
            local f=$_atuin_idfile
            _atuin_idfile=""
            ( local i=0
              while [[ ! -e $f ]] && (( i++ < 250 )); do sleep 0.02; done
              [[ -s $f ]] && atuin history end --hook --exit $EXIT ''${duration:+--duration=$duration} -- "$(<$f)"
              rm -f -- "$f" "$f.tmp" ) >/dev/null 2>&1 &!
          }
          # `exit` never reaches precmd: drop its pending id file when the shell quits, after
          # the background `start` (which may still be writing it) has had time to finish.
          _atuin_zshexit() {
            [[ -n $_atuin_idfile ]] || return 0
            local f=$_atuin_idfile
            ( sleep 5; rm -f -- "$f" "$f.tmp" ) >/dev/null 2>&1 &!
          }
          autoload -Uz add-zsh-hook && add-zsh-hook zshexit _atuin_zshexit
        '')
      ];

      programs.atuin = {
        enable = true;
        # Search UI patched (no settings exist for this):
        # - ❯ marks the selected row; the filter's icon (G global,  git repo, D directory,
        #   S session) replaces the `[ GLOBAL ]` badge; the query sits in the commands' column.
        # - Right side, dim, only when not in the default state: the search mode (prefix /
        #   full text), "context", vim's "normal" mode or a half-typed vim command (2d, ci …).
        # - Vim normal mode for the query: counts, d c y with motions and text objects, f F t T
        #   ; , x X s S r ~ D C Y p P, u / Ctrl-R undo-redo, i a I A, / (new search); for the
        #   list j k gg G H M L Ctrl-U/D/B/F/N/P. Keys the keymap below doesn't bind go to it.
        # - [keymap] tables are complete: a mode with a table has only those keys.
        # - The selection stays on its command when the filter, search mode or context
        #   changes (also through filters that don't list it), and in place after a delete.
        # - The list scrolls only at its edge, one row of context kept (as vim's scrolloff=1).
        # - Each frame goes out in one write, as a synchronized update: the cursor no longer
        #   flashes at the selection or blinks at the query while the list redraws.
        # - toggle-tab: details view instead of the inspector tab: rows get ui.details_columns,
        #   and two lines under the list show the selected command's stats (runs, average
        #   duration, exit codes, time of this run) and the commands run before/after it.
        # - Context (switch-context): leaving it restores the query typed before.
        # - Delete mode (enter-prefix-mode): red trash icon; typing still searches; Del
        #   deletes the selected command (every run), Shift-Del twice every command listed.
        # Written against 18.21; built locally (no binary cache has it); if atuin changes
        # that code, the patch fails and so does the build.
        package = pkgs.atuin.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./atuin-search.patch ];
        });
        # zsh hooks + Ctrl-R come from the prebuilt init script above, not HM's per-shell eval.
        enableZshIntegration = false;
        # ↑ stays zsh's instant in-memory history (this terminal); Ctrl-R opens atuin's search.
        # No AI hook: otherwise `?` on an empty prompt opens atuin AI (a hosted assistant that
        # can read history and files and run commands). Off in settings too (ai.enabled).
        flags = [
          "--disable-up-arrow"
          "--disable-ai"
        ];
        daemon.enable = false; # the daemon only serves background sync, which is off

        settings = {
          # --- Storage
          data_dir = "${config.xdg.dataHome}/atuin"; # base folder (persistent /home)
          db_path = "${config.xdg.dataHome}/atuin/history.db"; # the SQLite history database
          key_path = "${config.xdg.dataHome}/atuin/key"; # encrypts history for sync (sync is off)

          # --- Time display
          dialect = "uk"; # day/month dates (06/10), not US month/day
          timezone = "local"; # the system timezone (follows a roaming host automatically)

          # --- Sync & updates: local-only, Nix manages versions
          auto_sync = false; # history never leaves this machine
          update_check = false; # no phoning home; versions come from the flake lock
          update_channel = "stable"; # irrelevant with Nix-managed versions; declared for completeness
          # Unused: with auto_sync off and no `atuin login`, nothing is sent. (Self-hosting
          # an atuin server later would point this at it.)
          sync_address = "https://api.atuin.sh";
          sync_frequency = "5m"; # inactive while sync is off

          # --- Search behavior
          # Fragments in order match: `gco mn` finds `git checkout main`; also ^start end$
          # 'exact !exclude inside a query.
          search_mode = "fuzzy";
          # If atuin ever takes up-arrow (disabled above): classic "starts with" behavior.
          search_mode_shell_up_key_binding = "prefix";
          # Ctrl-R opens on all history; Alt-R cycles the narrower filters
          # (order: search.filters below).
          filter_mode = "global";
          filter_mode_shell_up_key_binding = "session"; # if atuin ever takes up-arrow: this terminal
          workspaces = true; # filter "workspace" = commands run anywhere in the current git repo
          # After `&&`, `||` or `|`, the picked command is appended instead of replacing the line.
          command_chaining = true;
          # Enter puts the picked command on the prompt instead of running it, so you see
          # it first (same idea as HIST_VERIFY). One more Enter runs it. Inactive: the keymap
          # below binds Enter itself (return-selection, the same behavior).
          enter_accept = false;
          # Esc in normal mode closes the search and keeps what you typed on the prompt.
          exit_mode = "return-query";

          # --- What gets recorded
          # Security: commands containing AWS/GitHub/Slack/Stripe-style keys are never stored.
          secrets_filter = true;
          # gitleaks' 221 rules + ours, ASCII-fied (see the top of this file).
          history_filter = secretPatterns;
          store_failed = true; # failed commands are kept, with their exit code
          strip_trailing_whitespace = true; # `git status ` = `git status` (escaped spaces kept)
          # Commands run inside these directories (regexes on the cwd) aren't recorded.
          cwd_filter = [
            "^${config.home.homeDirectory}/\\.ssh(/|$)" # working with private keys
            "/secrets(/|$)" # any `secrets` dir, e.g. the config repo's sops files
          ];
          # `atuin history list` lines: fixed-width fields first, the command last (for cut/awk).
          history_format = "{time}\t{exit}\t{duration}\t{command}";

          # --- Search UI (Ctrl-R)
          style = "compact"; # one dense line per command
          # Opens below the prompt (scrollback stays visible): the search line + 10 rows.
          inline_height = 11;
          inline_height_shell_up_key_binding = 11; # same, if atuin ever takes up-arrow
          # Search line right under the prompt, results flowing down (newest first): unused
          # rows fall below the list, never as a gap between the prompt and the history.
          invert = true;
          # No preview line repeating the selected command (it also resized the list): long
          # commands are shortened in the middle with …, and land complete on the prompt.
          show_preview = false;
          max_preview_height = 4; # inactive while show_preview is off
          show_help = false; # no header row (version, key hints, history count); one more result line
          show_tabs = false; # no "Search │ Inspect" row; the inspector is replaced by Alt-I details
          auto_hide_height = 8; # windows of ≤8 lines (tiny panes) switch to the 1-line compact form
          show_numeric_shortcuts = false; # no 1–9 beside results (↓ is quicker than Alt+N)
          # Inactive: the keymap below binds no digit shortcuts (it would mean Alt+digit).
          ctrl_n_shortcuts = false;
          scroll_context_lines = 1; # paging keeps one line of overlap, so you don't lose your place
          # Inactive: only atuin's emacs word actions use it; vim motions don't.
          word_jump_mode = "emacs";
          # Word characters for vim's w b e, iw, Ctrl-W (vim's 'iskeyword'): letters, digits and
          # _ in ASCII + Ukrainian/Russian; other non-blanks form words of their own (`-am`).
          word_chars =
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
            + "абвгґдеєжзиіїйклмнопрстуфхцчшщьюяАБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"
            + "ёъыэЁЪЫЭ";
          prefers_reduced_motion = false; # live timers in the UI keep updating
          # Vim, whatever the shell's mode: the search opens in insert mode (type to search),
          # Esc for normal mode (vim editing, j/k through results), i to type again.
          keymap_mode = "vim-insert";
          # A solid block in every mode (as in the editor); "normal" on the right shows the mode.
          # On close the terminal's own cursor comes back.
          keymap_cursor = {
            emacs = "steady-block";
            vim_insert = "steady-block";
            vim_normal = "steady-block";
          };

          # --- Timeouts (seconds)
          network_connect_timeout = 5; # sync server connect; inactive while sync is off
          network_timeout = 30; # a whole sync request; inactive while sync is off
          # Waiting for the SQLite lock when several shells record at once (in the background).
          local_timeout = 2;
          extra_headers = { }; # HTTP headers for a proxied sync server; no sync

          # --- `atuin stats`
          # Counted per subcommand (git commit ≠ git push): atuin's list + tools used here.
          stats.common_subcommands = [
            "apt"
            "cargo"
            "composer"
            "dnf"
            "docker"
            "dotnet"
            "git"
            "go"
            "ip"
            "jj"
            "kubectl"
            "nix"
            "nmcli"
            "npm"
            "pecl"
            "pnpm"
            "podman"
            "port"
            "systemctl"
            "tmux"
            "yarn"
            "nh"
            "uv"
            "tailscale"
            "sops"
          ];
          stats.common_prefix = [ "sudo" ]; # `sudo systemctl …` counts as systemctl
          # Left out of stats (still recorded and searchable): they'd always top the list.
          stats.ignored_commands = [
            "cd"
            "ls"
            "pwd"
            "clear"
            "exit"
          ];

          # --- [keys]: inactive, atuin ignores it while [keymap] (below) has entries. Set to
          # what the keymap does, in case it's ever removed.
          keys.scroll_exits = false; # ↑ at the newest result stays put (doesn't close the search)
          keys.exit_past_line_start = false; # ← only moves the cursor (as in vim)
          keys.accept_past_line_end = false; # → only moves the cursor (as in vim)
          keys.accept_past_line_start = false;
          keys.accept_with_backspace = false; # Backspace only deletes, never accepts

          # --- Keys in the search UI: vim for the query, atuin's own on Alt (both modes).
          # Each table is the mode's complete keymap (patched). In normal mode, keys not listed
          # are vim commands (see the patch notes above): j k gg G … move through the results.
          keymap =
            let
              both = {
                "alt-r" = "cycle-filter-mode"; # G → git → D → S; the selection stays on its command
                "alt-s" = "cycle-search-mode"; # fuzzy → prefix → full text
                # The selected command's terminal session (Alt-R: its directory, its repo);
                # Alt-C again: back to the query you had.
                "alt-c" = [
                  {
                    when = "has-context";
                    action = "clear-context";
                  }
                  { action = "switch-context"; }
                ];
                "alt-i" = "toggle-tab"; # details: exit, duration, when, where + 2 stats lines
                "alt-d" = "enter-prefix-mode"; # delete mode, on/off
                "alt-y" = "copy"; # the selected command to the clipboard (closes the search)
                "enter" = "return-selection"; # onto the prompt, not run
                "ctrl-c" = "return-original"; # close; the prompt as it was
                "down" = "select-next";
                "up" = "select-previous"; # at the newest result: stays
                "pagedown" = "scroll-page-down";
                "pageup" = "scroll-page-up";
              };
            in
            {
              # Typing searches; the rest is vim's insert mode.
              vim-insert = both // {
                "esc" = "vim-enter-normal";
                "ctrl-[" = "vim-enter-normal";
                "ctrl-n" = "select-next"; # as in vim's completion menu
                "ctrl-p" = "select-previous";
                "left" = "cursor-left";
                "right" = "cursor-right";
                "home" = "cursor-start";
                "end" = "cursor-end";
                "backspace" = "delete-char-before";
                "ctrl-h" = "delete-char-before";
                "delete" = "delete-char-after";
                "ctrl-w" = "vim-delete-word-before"; # vim's word rules (patched)
                "ctrl-u" = "clear-to-start";
              };
              vim-normal = both // {
                "esc" = "exit"; # close; the query stays on the prompt (exit_mode)
                "ctrl-[" = "exit";
                "ctrl-l" = "redraw";
              };
              # Delete mode (Alt-D), checked first; all other keys work as usual.
              prefix = {
                "delete" = "delete-all"; # the selected command, every run of it
                "shift-delete" = "delete-all-results"; # twice: every command listed
                "esc" = "enter-prefix-mode"; # leave delete mode
              };
            };

          # --- Preview: as tall as the selected command needs (max: max_preview_height);
          # inactive while show_preview is off
          preview.strategy = "auto";

          # --- Daemon: only for sync / daemon-fuzzy search; neither is used
          daemon.enabled = false; # record straight into SQLite
          daemon.autostart = false; # never spawn an undeclared background process
          daemon.sync_frequency = 300; # inactive (no daemon, no sync)
          daemon.systemd_socket = false; # if ever needed: this + a declared systemd user socket
          daemon.tcp_port = 8889; # non-Unix systems only; Linux uses a socket file
          # daemon.socket_path / daemon.pidfile_path: atuin computes them at runtime (UID,
          # $TMPDIR); unused without a daemon, so left to atuin rather than hardcoded.

          # --- PTY proxy: would re-run the whole shell inside an atuin pseudo-terminal (an
          # extra process between every keystroke and zsh, startup files run twice). Off.
          pty_proxy.enabled = false;

          # --- AI: atuin's hosted assistant (`atuin ai`, chats that can search history, read and
          # write files, run commands). Off; it would send prompts to atuin's servers. The rest
          # is inactive while off, set so that turning it on grants nothing by default. Unset (no
          # TOML null): endpoint, api_token, model (atuin's hosted defaults).
          ai.enabled = false;
          ai.yolo = false; # every tool use asks first
          ai.capabilities.enable_history_search = false;
          ai.capabilities.enable_history_output = false;
          ai.capabilities.enable_file_tools = false;
          ai.capabilities.enable_command_execution = false;
          ai.opening.send_cwd = false; # nothing about the shell in the opening request
          ai.opening.send_last_command = false;
          ai.endpoint_protocol = "auto"; # Hub for atuin's endpoint, else an OSS server
          ai.session_continue_minutes = 60; # how long a chat can be resumed
          ai.db_path = "${config.xdg.dataHome}/atuin/ai_sessions.db"; # chat history
          ai.tips = false; # no feature tips in its UI

          # --- Theme: atuin's own for now; the Stylix (theming) step replaces it
          theme.name = "default";
          theme.debug = false; # diagnostics for writing custom themes only

          # --- Search: the filters Alt-R cycles through, broad → narrow. `host` equals
          # `global` on one machine and `session-preload` is a niche session variant: left out.
          search.filters = [
            "global"
            "workspace"
            "directory"
            "session"
          ];
          search.shells = "auto"; # only commands from the current shell type (zsh syntax)

          # --- tmux: inside tmux, Ctrl-R floats as a popup; the pane underneath (e.g. an
          # agent's output) stays untouched. Outside tmux it stays inline.
          tmux.enabled = true;
          tmux.width = "80%"; # wide for long commands, with a margin
          tmux.height = "60%"; # a good page of results; the pane stays visible around it

          # --- Result rows: just the command (after the ❯ marker), the full width.
          ui.columns = [ "command" ];
          # Alt-I (details view, patched in): the same rows with exit code, duration, how
          # long ago and where (directory, cut to 24 columns), plus two stats lines below.
          ui.details_columns = [
            "exit"
            "duration"
            "time"
            {
              type = "directory";
              width = 24;
            }
            "command"
          ];
          ui.syntax_highlight = true; # results colored like a shell line (theme palette)
        };
      };
    };
}

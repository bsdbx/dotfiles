# zsh history: in memory only. Each shell keeps its own commands (↑, `!!`, `sudo !!`) and
# forgets them on exit; no history file is written or read (HISTFILE is unset at the end).
{
  flake.modules.homeManager.history =
    { config, lib, ... }:
    let
      options = {
        BANG_HIST = true;
        HIST_ALLOW_CLOBBER = true;
        HIST_BEEP = false;
        HIST_LEX_WORDS = false;
        HIST_NO_FUNCTIONS = true;
        HIST_NO_STORE = true;
        HIST_REDUCE_BLANKS = true;
        HIST_SAVE_BY_COPY = true;
        HIST_VERIFY = true;
        INC_APPEND_HISTORY = false;
        INC_APPEND_HISTORY_TIME = false;
      };
    in
    {
      programs.zsh = {
        history = {
          path = "${config.xdg.stateHome}/zsh/history";
          size = 100000;
          save = 100000;
          ignorePatterns = [
            "ls"
            "cd"
            "cd -"
            "cd .."
            "pwd"
            "exit"
            "clear"
          ];


          append = true;
          extended = true;
          expireDuplicatesFirst = true;
          findNoDups = true;
          ignoreAllDups = true;
          ignoreDups = true;
          ignoreSpace = true;
          saveNoDups = true;
          share = true;
        };
        setOptions = lib.mapAttrsToList (name: on: if on then name else "NO_${name}") options;
        initContent = lib.mkOrder 911 "unset HISTFILE";
      };
    };
}

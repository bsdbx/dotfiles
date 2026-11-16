# zsh core: login shell, base options. Each other concern (history, completion, keys,
# prompt, …) is its own feature under modules/shell/ and declares its own options.
{
  # System layer: only what a login shell needs.
  flake.modules.nixos.zsh =
    { pkgs, ... }:
    {
      programs.zsh = {
        enable = true;
        enableCompletion = false;
        enableGlobalCompInit = false;
        enableLsColors = false;
        promptInit = "";
        setOptions = [ ];
        # No zsh history file for any user (root's shells included): NixOS always writes
        # HISTFILE into /etc/zshrc (this can't be empty), so it's unset again below. Each shell
        # keeps its in-memory history (↑, !!)
        histFile = "$HOME/.zsh_history";
        histSize = 2000;
        interactiveShellInit = "unset HISTFILE";
      };
      # Completions shipped by system packages.
      environment.pathsToLink = [ "/share/zsh" ];

      users.defaultUserShell = pkgs.zsh;
    };

  flake.modules.homeManager.zsh =
    { config, lib, ... }:
    let
      options = {
        # --- Changing directories
        AUTO_CD = true;
        AUTO_PUSHD = true;
        CDABLE_VARS = false;
        CD_SILENT = false;
        CHASE_DOTS = false;
        CHASE_LINKS = false;
        POSIX_CD = false;
        PUSHD_IGNORE_DUPS = true;
        PUSHD_MINUS = true;
        PUSHD_SILENT = true;
        PUSHD_TO_HOME = false;

        # --- Expansion and globbing
        BAD_PATTERN = true;
        BARE_GLOB_QUAL = true;
        BRACE_CCL = false;
        CASE_GLOB = true;
        CASE_MATCH = true;
        CASE_PATHS = false;
        CSH_NULL_GLOB = false;
        EQUALS = true;
        EXTENDED_GLOB = true;
        FORCE_FLOAT = false;
        GLOB = true;
        GLOB_ASSIGN = false;
        GLOB_DOTS = false;
        GLOB_STAR_SHORT = true;
        GLOB_SUBST = false;
        HIST_SUBST_PATTERN = false;
        IGNORE_BRACES = false;
        IGNORE_CLOSE_BRACES = false;
        KSH_GLOB = false;
        MAGIC_EQUAL_SUBST = true;
        MARK_DIRS = false;
        MULTIBYTE = true;
        NOMATCH = true;
        NULL_GLOB = false;
        NUMERIC_GLOB_SORT = true;
        RC_EXPAND_PARAM = false;
        REMATCH_PCRE = false;
        SH_GLOB = false;
        UNSET = true;
        WARN_CREATE_GLOBAL = false;
        WARN_NESTED_VAR = false;

        # --- Initialisation
        ALL_EXPORT = false;
        GLOBAL_EXPORT = true;
        GLOBAL_RCS = true;
        RCS = true;

        # --- Input/output
        ALIASES = true;
        CLOBBER = false;
        CLOBBER_EMPTY = true;
        CORRECT = false;
        CORRECT_ALL = false;
        DVORAK = false;
        FLOW_CONTROL = false;
        IGNORE_EOF = false;
        INTERACTIVE_COMMENTS = true;
        HASH_CMDS = true;
        HASH_DIRS = true;
        HASH_EXECUTABLES_ONLY = false;
        MAIL_WARNING = false;
        PATH_DIRS = false;
        PATH_SCRIPT = false;
        PRINT_EIGHT_BIT = false;
        PRINT_EXIT_VALUE = false;
        RC_QUOTES = true;
        RM_STAR_SILENT = false;
        RM_STAR_WAIT = true;
        SHORT_LOOPS = true;
        SHORT_REPEAT = false;
        SUN_KEYBOARD_HACK = false;

        # --- Job control
        AUTO_CONTINUE = true;
        AUTO_RESUME = false;
        BG_NICE = true;
        CHECK_JOBS = true;
        CHECK_RUNNING_JOBS = true;
        HUP = true;
        LONG_LIST_JOBS = true;
        NOTIFY = true;
        POSIX_JOBS = false;

        # --- Scripts and functions
        ALIAS_FUNC_DEF = false;
        C_BASES = false;
        C_PRECEDENCES = false;
        DEBUG_BEFORE_CMD = true;
        ERR_EXIT = false;
        ERR_RETURN = false;
        EVAL_LINENO = true;
        EXEC = true;
        FUNCTION_ARGZERO = true;
        LOCAL_LOOPS = false;
        LOCAL_OPTIONS = false;
        LOCAL_PATTERNS = false;
        LOCAL_TRAPS = false;
        MULTI_FUNC_DEF = true;
        MULTIOS = true;
        OCTAL_ZEROES = false;
        PIPE_FAIL = false;
        SOURCE_TRACE = false;
        TYPESET_SILENT = false;
        TYPESET_TO_UNSET = false;
        VERBOSE = false;
        XTRACE = false;

        # --- Shell emulation: all at zsh's defaults, so zsh syntax and plugins work as written
        APPEND_CREATE = false;
        BASH_REMATCH = false;
        BSD_ECHO = false;
        CONTINUE_ON_ERROR = false;
        CSH_JUNKIE_HISTORY = false;
        CSH_JUNKIE_LOOPS = false;
        CSH_JUNKIE_QUOTES = false;
        CSH_NULLCMD = false;
        KSH_ARRAYS = false;
        KSH_AUTOLOAD = false;
        KSH_OPTION_PRINT = false;
        KSH_TYPESET = false;
        KSH_ZERO_SUBSCRIPT = false;
        POSIX_ALIASES = false;
        POSIX_ARGZERO = false;
        POSIX_BUILTINS = false;
        POSIX_IDENTIFIERS = false;
        POSIX_STRINGS = false;
        POSIX_TRAPS = false;
        SH_FILE_EXPANSION = false;
        SH_NULLCMD = false;
        SH_OPTION_LETTERS = false;
        SH_WORD_SPLIT = false;
        TRAPS_ASYNC = false;
      };
    in
    {
      programs.zsh = {
        enable = true;
        # ~/.config/zsh/.zshrc etc.; ~/.zshenv only points zsh there.
        dotDir = "${config.xdg.configHome}/zsh";
        enableCompletion = lib.mkDefault false;
        setOptions = lib.mapAttrsToList (name: on: if on then name else "NO_${name}") options;

        # Shell parameters (zshparam(1)), set at the top of .zshrc.
        localVariables = {
          DIRSTACKSIZE = 20;
          WORDCHARS = "*?_[]~&;!#$%^(){}<>";
          REPORTTIME = 5;
          TIMEFMT = "%J  %*E wall · %U user · %S sys · %P cpu · %M KB max mem";
          READNULLCMD = "less";
        };

        # .zshenv: read by every zsh, scripts included.
        envExtra = ''
          # Here-docs and =(…) temp files go to the private, RAM-only runtime dir
          # (/run/user/UID, mode 0700) instead of world-listable /tmp.
          TMPPREFIX="''${XDG_RUNTIME_DIR:-/tmp}/zsh"
        '';

        # Bundled zsh utilities, loaded on first use.
        #   zmv      batch rename: zmv '(*).jpeg' '$1.jpg'   (zmv -n = preview)
        #   zcalc    interactive calculator
        #   run-help context-aware help (builtins, git, sudo, ip…); bound to Alt-H by keys
        initContent = ''
          autoload -Uz zmv zcalc run-help run-help-git run-help-ip run-help-sudo
          (( ''${+aliases[run-help]} )) && unalias run-help
        '';
      };
    };
}

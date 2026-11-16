{
  flake.modules.homeManager.prompt =
    { lib, ... }:
    let
      options = {
        PROMPT_PERCENT = true;
        PROMPT_SUBST = false;
        PROMPT_BANG = false;
        PROMPT_CR = true;
        PROMPT_SP = true;
        TRANSIENT_RPROMPT = false;
      };
    in
    {
      programs.zsh = {
        setOptions = lib.mapAttrsToList (name: on: if on then name else "NO_${name}") options;
        initContent = lib.mkOrder 1500 "source ${./prompt.zsh}";
      };
    };
}

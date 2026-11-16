# bohdan's home directory layout:
#   ~/docs  ~/notes  ~/media/{pics,vids}  ~/src/{<host>/<owner>/<repo>, local/<name>, uni/<course>}
#   ~/dl  ~/tmp   ← RAM-backed, empty after every boot

{
  flake.modules.nixos.bohdan =
    { config, ... }:
    let
      user = config.users.users.bohdan;
      ramDir = size: extra: {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [
          "size=${size}"
          "mode=0700"
          "uid=${toString user.uid}"
          "gid=${toString config.users.groups.${user.group}.gid}"
          "nosuid"
          "nodev"
        ]
        ++ extra;
      };
    in
    {
      # Downloads
      fileSystems."${user.home}/dl" = ramDir "16G" [ "noexec" ];
      # tmp/
      fileSystems."${user.home}/tmp" = ramDir "8G" [ ];
    };

  flake.modules.homeManager.bohdan =
    { config, ... }:
    let
      home = config.home.homeDirectory;
    in
    {
      # ~/.config/user-dirs.dirs
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = true; # also export XDG_DOWNLOAD_DIR etc. for scripts
        documents = "${home}/docs";
        download = "${home}/dl";
        pictures = "${home}/media/pics";
        videos = "${home}/media/vids"; # screen recordings
        projects = "${home}/src"; # <host>/<owner>/<repo>, local/<name>, uni/<course>
        desktop = home;
        music = home;
        templates = home;
        publicShare = home;
        extraConfig.SCREENSHOTS = "${home}/media/pics/screenshots"; # → XDG_SCREENSHOTS_DIR
      };

      # Non-XDG folders
      systemd.user.tmpfiles.rules = [
        "d %h/notes - - - -" # Obsidian vault
        "d %h/src/local - - - -" # projects without a remote
        "d %h/src/uni - - - -" # coursework: uni/<course>/{<repos>, materials/}
      ];

      # Named directories
      programs.zsh.dirHashes = {
        cfg = "${home}/src/github.com/bsdbx/nixos-config";
        src = "${home}/src";
        notes = "${home}/notes";
      };
      # One named directory per course: ~/src/uni/sdt208 → ~sdt208
      programs.zsh.initContent = ''
        for _course in ${home}/src/uni/*(N/); do hash -d -- "''${_course:t}=$_course"; done
        unset _course
      '';
    };
}

{
  description = "ii-material-sddm: Material Design 3 SDDM theme inspired by the ii lockscreen";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPackage = pkgs: pkgs.callPackage ./packaging/nix/package.nix { src = self; };
    in
    {
      packages = forAllSystems (
        system:
        let
          inherit (nixpkgs.legacyPackages.${system}) callPackage;
          ii-material-sddm = callPackage ./packaging/nix/package.nix { src = self; };
        in
        {
          inherit ii-material-sddm;
          default = ii-material-sddm;
        }
      );

      overlays.default = final: _prev: {
        ii-material-sddm = mkPackage final;
      };

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.ii-material-sddm;
        in
        {
          options.services.ii-material-sddm = {
            enable = lib.mkEnableOption "the ii-material-sddm SDDM login theme";

            user = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "kazu";
              description = ''
                Grant the sddm greeter read access to this user's matugen state
                (~/.local/state/quickshell/user/generated) so the login screen
                follows the active ii wallpaper and color scheme.
              '';
            };
          };

          config = lib.mkMerge [
            (lib.mkIf cfg.enable {
              services.displayManager.sddm = {
                enable = true;
                package = lib.mkDefault pkgs.kdePackages.sddm;
                theme = "ii-material-sddm";
                settings.General.GreeterEnvironment = "QML_XHR_ALLOW_FILE_READ=1";
              };
              environment.systemPackages = [ (mkPackage pkgs) ];
              fonts.packages = [ pkgs.material-symbols ];
            })

            (lib.mkIf (cfg.enable && cfg.user != null) {
              systemd.services.ii-material-sddm-acl =
                let
                  setfacl = "${pkgs.acl}/bin/setfacl";
                  home = "/home/${cfg.user}";
                  base = "${home}/.local/state/quickshell/user/generated";
                in
                {
                  description = "Grant sddm read access to ii-material-sddm matugen state";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "local-fs.target" ];
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  script = ''
                    for dir in \
                      ${home} \
                      ${home}/.local \
                      ${home}/.local/state \
                      ${home}/.local/state/quickshell \
                      ${home}/.local/state/quickshell/user \
                      ${base}
                    do
                      if [ -d "$dir" ]; then
                        ${setfacl} -m u:sddm:--x "$dir"
                      fi
                    done
                    if [ -d ${base} ]; then
                      ${setfacl} -Rm u:sddm:r-- ${base}
                      ${setfacl} -Rm d:u:sddm:r-- ${base}
                    fi
                  '';
                };
            })
          ];
        };
    };
}

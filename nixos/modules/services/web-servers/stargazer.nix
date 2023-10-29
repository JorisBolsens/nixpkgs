{ config, lib, pkgs, ... }:

let
  cfg = config.services.stargazer;
  globalSection = ''
    listen = ${lib.concatStringsSep " " cfg.listen}
    connection-logging = ${lib.boolToString cfg.connectionLogging}
    log-ip = ${lib.boolToString cfg.ipLog}
    log-ip-partial = ${lib.boolToString cfg.ipLogPartial}
    request-timeout = ${toString cfg.requestTimeout}
    response-timeout = ${toString cfg.responseTimeout}

    [:tls]
    store = ${toString cfg.store}
    organization = ${cfg.certOrg}
    gen-certs = ${lib.boolToString cfg.genCerts}
    regen-certs = ${lib.boolToString cfg.regenCerts}
    ${lib.optionalString (cfg.certLifetime != "") "cert-lifetime = ${cfg.certLifetime}"}

  '';
  genINI = lib.generators.toINI { };
  configFile = pkgs.writeText "config.ini" (lib.strings.concatStrings (
    [ globalSection ] ++ (lib.lists.forEach cfg.routes (section:
      let
        name = section.route;
        params = builtins.removeAttrs section [ "route" ];
      in
      genINI
        {
          "${name}" = params;
        } + "\n"
    ))
  ));
in
{
  options.services.stargazer = {
    enable = lib.mkEnableOption (lib.mdDoc "Stargazer Gemini server");

    listen = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "0.0.0.0" ] ++ lib.optional config.networking.enableIPv6 "[::0]";
      defaultText = lib.literalExpression ''[ "0.0.0.0" ] ++ lib.optional config.networking.enableIPv6 "[::0]"'';
      example = lib.literalExpression ''[ "10.0.0.12" "[2002:a00:1::]" ]'';
      description = lib.mdDoc ''
        Address and port to listen on.
      '';
    };

    connectionLogging = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = lib.mdDoc "Whether or not to log connections to stdout.";
    };

    ipLog = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Log client IP addresses in the connection log.";
    };

    ipLogPartial = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Log partial client IP addresses in the connection log.";
    };

    requestTimeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = lib.mdDoc ''
        Number of seconds to wait for the client to send a complete
        request. Set to 0 to disable.
      '';
    };

    responseTimeout = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = lib.mdDoc ''
        Number of seconds to wait for the client to send a complete
        request and for stargazer to finish sending the response.
        Set to 0 to disable.
      '';
    };

    store = lib.mkOption {
      type = lib.types.path;
      default = /var/lib/gemini/certs;
      description = lib.mdDoc ''
        Path to the certificate store on disk. This should be a
        persistent directory writable by Stargazer.
      '';
    };

    certOrg = lib.mkOption {
      type = lib.types.str;
      default = "stargazer";
      description = lib.mdDoc ''
        The name of the organization responsible for the X.509
        certificate's /O name.
      '';
    };

    genCerts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = lib.mdDoc ''
        Set to false to disable automatic certificate generation.
        Use if you want to provide your own certs.
      '';
    };

    regenCerts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = lib.mdDoc ''
        Set to false to turn off automatic regeneration of expired certificates.
        Use if you want to provide your own certs.
      '';
    };

    certLifetime = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = lib.mdDoc ''
        How long certs generated by Stargazer should live for.
        Certs live forever by default.
      '';
      example = lib.literalExpression "\"1y\"";
    };

    routes = lib.mkOption {
      type = lib.types.listOf
        (lib.types.submodule {
          freeformType = with lib.types; attrsOf (nullOr
            (oneOf [
              bool
              int
              float
              str
            ]) // {
            description = "INI atom (null, bool, int, float or string)";
          });
          options.route = lib.mkOption {
            type = lib.types.str;
            description = lib.mdDoc "Route section name";
          };
        });
      default = [ ];
      description = lib.mdDoc ''
        Routes that Stargazer should server.

        Expressed as a list of attribute sets. Each set must have a key `route`
        that becomes the section name for that route in the stargazer ini cofig.
        The remaining keys and values become the parameters for that route.

        [Refer to upstream docs for other params](https://git.sr.ht/~zethra/stargazer/tree/main/item/doc/stargazer.ini.5.txt)
      '';
      example = lib.literalExpression ''
        [
          {
            route = "example.com";
            root = "/srv/gemini/example.com"
          }
          {
            route = "example.com:/man";
            root = "/cgi-bin";
            cgi = true;
          }
          {
            route = "other.org~(.*)";
            redirect = "gemini://example.com";
            rewrite = "\1";
          }
        ]
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "stargazer";
      description = lib.mdDoc "User account under which stargazer runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "stargazer";
      description = lib.mdDoc "Group account under which stargazer runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.stargazer = {
      description = "Stargazer gemini server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.stargazer}/bin/stargazer ${configFile}";
        Restart = "always";
        # User and group
        User = cfg.user;
        Group = cfg.group;
      };
    };

    # Create default cert store
    systemd.tmpfiles.rules = lib.mkIf (cfg.store == /var/lib/gemini/certs) [
      ''d /var/lib/gemini/certs - "${cfg.user}" "${cfg.group}" -''
    ];

    users.users = lib.optionalAttrs (cfg.user == "stargazer") {
      stargazer = {
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "stargazer") {
      stargazer = { };
    };
  };

  meta.maintainers = with lib.maintainers; [ gaykitty ];
}

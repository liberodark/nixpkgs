{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rundeck;
in
{
  options.services.rundeck = {
    enable = lib.mkEnableOption "Rundeck service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rundeck;
      defaultText = lib.literalExpression "pkgs.rundeck";
      description = "Rundeck package to use";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "rundeck";
      description = "User account under which Rundeck runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "rundeck";
      description = "Group account under which Rundeck runs";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rundeck";
      description = "Directory for Rundeck runtime data (RDECK_BASE)";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/etc/rundeck";
      description = "Directory for Rundeck configuration files";
    };

    tempDir = lib.mkOption {
      type = lib.types.path;
      default = "/tmp/rundeck";
      description = "Temporary directory for Rundeck";
    };

    workDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rundeck/work";
      description = "Working directory for Rundeck";
    };

    logDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rundeck/logs";
      description = "Log directory for Rundeck";
    };

    javaOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "-Xmx1024m"
        "-Xms256m"
        "-XX:MaxMetaspaceSize=256m"
        "-server"
        "-Djava.io.tmpdir=/tmp/rundeck"
        "-Drundeck.jetty.connector.forwarded=true"
      ];
      description = "Additional Java options for Rundeck";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "h2"
          "postgresql"
          "mysql"
        ];
        default = "h2";
        description = "Database type to use (h2, postgresql, or mysql)";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Database host";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "Database port";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "rundeck";
        description = "Database name";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "rundeck";
        description = "Database username";
      };

      password = lib.mkOption {
        type = lib.types.str;
        default = "rundeck";
        description = "Database password";
      };
    };

    jaas = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable JAAS login";
      };

      configFile = lib.mkOption {
        type = lib.types.path;
        default = "/etc/rundeck/jaas-loginmodule.conf";
        description = "JAAS configuration file";
      };

      loginModule = lib.mkOption {
        type = lib.types.str;
        default = "RDpropertyfilelogin";
        description = "JAAS login module to use";
      };
    };

    properties = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "server.address" = "0.0.0.0";
        "server.port" = "4440";
        "grails.serverURL" = "http://localhost:4440";
      };
      description = "Additional properties for rundeck-config.properties";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/rundeck/rundeck.env";
      description = "Environment file containing additional environment variables";
    };

    ssl = {
      enable = lib.mkEnableOption "SSL support";

      keyStore = lib.mkOption {
        type = lib.types.path;
        example = "/etc/rundeck/ssl/keystore";
        description = "Path to the keystore containing the SSL certificate";
      };

      keyStorePassword = lib.mkOption {
        type = lib.types.str;
        description = "Password for the SSL keystore";
      };

      keyPassword = lib.mkOption {
        type = lib.types.str;
        description = "Password for the SSL key";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d '${cfg.tempDir}' 0750 ${cfg.user} ${cfg.group} -"
      "d '${cfg.workDir}' 0750 ${cfg.user} ${cfg.group} -"
      "d '${cfg.logDir}' 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.rundeck = {
      description = "Rundeck Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = lib.optional (cfg.database.type == "mysql") "mysql.service";

      environment = {
        RDECK_BASE = cfg.dataDir;
        RDECK_CONFIG = cfg.configDir;
        RUNDECK_TEMPDIR = cfg.tempDir;
        RUNDECK_WORKDIR = cfg.workDir;
        RUNDECK_LOGDIR = cfg.logDir;
        JAVA_OPTS = lib.concatStringsSep " " (
          cfg.javaOpts
          ++ [
            "-Drundeck.jaaslogin=${lib.boolToString cfg.jaas.enable}"
            "-Djava.security.auth.login.config=${cfg.jaas.configFile}"
            "-Dloginmodule.name=${cfg.jaas.loginModule}"
            "-Drdeck.config=${cfg.configDir}"
            "-Drundeck.server.configDir=${cfg.configDir}"
            "-Dserver.datastore.path=${cfg.dataDir}/data/rundeck"
            "-Drdeck.projects=${cfg.dataDir}/projects"
            "-Drdeck.runlogs=${cfg.logDir}"
            "-Drundeck.server.logDir=${cfg.logDir}"
            "-Drundeck.config.location=${cfg.configDir}/rundeck-config.properties"
            "-Drundeck.server.workDir=${cfg.workDir}"
            "-Drdeck.base=${cfg.dataDir}"
          ]
          ++ lib.optionals cfg.ssl.enable [
            "-Drundeck.ssl.config=${cfg.configDir}/ssl/ssl.properties"
            "-Dserver.https.port=4443"
          ]
        );
      };

      serviceConfig =
        {
          User = cfg.user;
          Group = cfg.group;
          ExecStart = lib.getExe cfg.package;
          WorkingDirectory = cfg.dataDir;
          RuntimeDirectory = "rundeck";
          RuntimeDirectoryMode = "0750";
          UMask = "0027";

          LimitNOFILE = 65536;
          ReadWritePaths = [
            cfg.dataDir
            cfg.configDir
            cfg.tempDir
            cfg.workDir
            cfg.logDir
          ];
          RestartSec = "10s";
          Restart = "always";
          TimeoutStartSec = "5min";
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = [ cfg.environmentFile ];
        };

      preStart = ''
        install -d -m750 -o ${cfg.user} -g ${cfg.group} \
          ${cfg.dataDir}/{data,projects,logs,libext} \
          ${cfg.configDir}

        cat > ${cfg.configDir}/rundeck-config.properties <<EOF
        server.address=0.0.0.0
        server.port=4440
        grails.serverURL=http${lib.optionalString cfg.ssl.enable "s"}://localhost:4440
        rundeck.log4j.config.file=${cfg.configDir}/log4j.properties
        rundeck.projectsStorageType=db

        ${
          if cfg.database.type == "h2" then
            ''
              dataSource.url=jdbc:h2:file:${cfg.dataDir}/data/rundeckdb;MVCC=true
              dataSource.driverClassName=org.h2.Driver
            ''
          else if cfg.database.type == "postgresql" then
            ''
              dataSource.url=jdbc:postgresql://${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}
              dataSource.driverClassName=org.postgresql.Driver
            ''
          else
            ''
              dataSource.url=jdbc:mysql://${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}?autoReconnect=true&useSSL=false
              dataSource.driverClassName=org.mariadb.jdbc.Driver
              dataSource.properties.validationQuery=select 1
              dataSource.hibernate.dialect=org.hibernate.dialect.MariaDB103Dialect
            ''
        }
        dataSource.username=${cfg.database.username}
        dataSource.password=${cfg.database.password}

        ${lib.optionalString cfg.ssl.enable ''
          server.https.port=4443
          server.ssl.keyStore=${cfg.ssl.keyStore}
          server.ssl.keyStorePassword=${cfg.ssl.keyStorePassword}
          server.ssl.keyPassword=${cfg.ssl.keyPassword}
        ''}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}=${value}") cfg.properties)}
        EOF

        cat > ${cfg.configDir}/log4j.properties <<EOF
        log4j.rootLogger=INFO, console, server-logger

        log4j.appender.console=org.apache.log4j.ConsoleAppender
        log4j.appender.console.layout=org.apache.log4j.PatternLayout
        log4j.appender.console.layout.ConversionPattern=%d{ISO8601} %-5p %c{1} - %m%n

        log4j.appender.server-logger=org.apache.log4j.DailyRollingFileAppender
        log4j.appender.server-logger.file=${cfg.logDir}/rundeck.log
        log4j.appender.server-logger.datePattern='.'yyyy-MM-dd
        log4j.appender.server-logger.layout=org.apache.log4j.PatternLayout
        log4j.appender.server-logger.layout.ConversionPattern=%d{ISO8601} [%t] %-5p %c - %m%n
        EOF

        chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir} ${cfg.configDir}
        chmod -R u=rwX,g=rX,o= ${cfg.dataDir} ${cfg.configDir}
      '';
    };

    networking.firewall.allowedTCPPorts = [ 4440 ];
  };
}

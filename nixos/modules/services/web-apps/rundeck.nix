{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rundeck;
  formatConfig = lib.mapAttrsToList (name: value: "${name}=${toString value}");
in
{
  options = {
    services.rundeck = {
      enable = lib.mkEnableOption "Rundeck service";

      package = lib.mkPackageOption pkgs "rundeck" { };

      adminUser = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Username for the Rundeck admin user";
        example = "rundeck-admin";
      };

      adminPassword = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Password for the Rundeck admin user";
        example = "securePassword123";
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

      serverHostname = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Hostname for the Rundeck server";
      };

      serverUUID = lib.mkOption {
        type = lib.types.str;
        default = "2a7e9fd7-cdd5-4e53-a80d-2d44091cea4a";
        description = "UUID for the Rundeck server";
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

      javaOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "-Xmx1024m"
          "-Xms256m"
          "-XX:MaxMetaspaceSize=256m"
          "-server"
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

      settings = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.oneOf [
            lib.types.bool
            lib.types.int
            lib.types.str
          ]
        );
        default = { };
        description = ''
          Rundeck configuration options.
          See https://docs.rundeck.com/docs/administration/configuration/config-file-reference.html
          for all available options.
        '';
        example = lib.literalExpression ''
          {
            "server.address" = "0.0.0.0";
            "server.port" = "4440";
            "grails.serverURL" = "http://rundeck.example.com:4440";
            "rundeck.projectsStorageType" = "db";
          }
        '';
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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.database.type == "h2" -> true;
        message = "When using H2 database, no additional configuration is needed";
      }
      {
        assertion = cfg.database.type != "h2" -> cfg.database.password != "";
        message = "Database password must be set when not using H2 database";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/logs 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/projects 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/libext 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/var 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/var/tmp 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/.ssh 0700 ${cfg.user} ${cfg.group} -"
      "d ${cfg.configDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.configDir}/ssl 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.tempDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.rundeck = {
      description = "Rundeck Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = lib.optional (cfg.database.type == "mysql") "mysql.service";

      environment = {
        RDECK_BASE = cfg.dataDir;
        RUNDECK_CONFIG_DIR = cfg.configDir;
        JAVA_OPTS = lib.concatStringsSep " " cfg.javaOpts;
      };

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = toString (
          pkgs.writeShellScript "start-rundeck" ''
            # Generate SSH key if it doesn't exist
            if [ ! -f ${cfg.dataDir}/.ssh/id_rsa ]; then
              ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -N "" -f ${cfg.dataDir}/.ssh/id_rsa
              chmod 600 ${cfg.dataDir}/.ssh/id_rsa
              chmod 644 ${cfg.dataDir}/.ssh/id_rsa.pub
            fi

            ${lib.getExe cfg.package} \
              --skipinstall \
              -b ${cfg.dataDir} \
              -c ${cfg.configDir} \
              -p ${cfg.dataDir}/projects
          ''
        );
        WorkingDirectory = cfg.dataDir;
        RuntimeDirectory = "rundeck";
        RuntimeDirectoryMode = "0750";
        UMask = "0027";

        LimitNOFILE = 65536;
        ReadWritePaths = [
          cfg.dataDir
          cfg.configDir
          cfg.tempDir
        ];
        RestartSec = "10s";
        Restart = "always";
        TimeoutStartSec = "5min";
      };

      preStart = ''
        cat > ${cfg.configDir}/rundeck-config.properties <<EOF
        ${lib.concatStringsSep "\n" (
          formatConfig (
            cfg.settings
            // {
              "server.address" = "0.0.0.0";
              "server.port" = "4440";
              "grails.serverURL" = "http${lib.optionalString cfg.ssl.enable "s"}://${cfg.serverHostname}";
              "logging.config" = "${cfg.configDir}/log4j2.properties";
              "dataSource.url" =
                if cfg.database.type == "h2" then
                  "jdbc:h2:file:${cfg.dataDir}/data/rundeckdb;MVCC=true"
                else if cfg.database.type == "postgresql" then
                  "jdbc:postgresql://${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}"
                else
                  "jdbc:mysql://${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}?autoReconnect=true&useSSL=false";
              "dataSource.driverClassName" =
                if cfg.database.type == "h2" then
                  "org.h2.Driver"
                else if cfg.database.type == "postgresql" then
                  "org.postgresql.Driver"
                else
                  "org.mariadb.jdbc.Driver";
              "dataSource.username" = cfg.database.username;
              "dataSource.password" = cfg.database.password;
            }
            // lib.optionalAttrs (cfg.database.type == "mysql") {
              "dataSource.properties.validationQuery" = "select 1";
              "dataSource.dialect" = "org.hibernate.dialect.MariaDB103Dialect";
            }
            // lib.optionalAttrs cfg.ssl.enable {
              "server.https.port" = "4443";
              "server.ssl.keyStore" = toString cfg.ssl.keyStore;
              "server.ssl.keyStorePassword" = cfg.ssl.keyStorePassword;
              "server.ssl.keyPassword" = cfg.ssl.keyPassword;
            }
          )
        )}
        EOF

        cat > ${cfg.configDir}/framework.properties <<EOF
        framework.server.name = ${cfg.serverHostname}
        framework.server.hostname = ${cfg.serverHostname}
        framework.server.port = 4440
        framework.server.url = http${lib.optionalString cfg.ssl.enable "s"}://${cfg.serverHostname}
        rdeck.base = ${cfg.dataDir}
        framework.projects.dir = ${cfg.dataDir}/projects
        framework.etc.dir = ${cfg.configDir}
        framework.var.dir = ${cfg.dataDir}/var
        framework.tmp.dir = ${cfg.dataDir}/var/tmp
        framework.logs.dir = ${cfg.dataDir}/logs
        framework.libext.dir = ${cfg.dataDir}/libext
        framework.ssh.keypath = ${cfg.dataDir}/.ssh/id_rsa
        framework.ssh.user = ${cfg.user}
        framework.ssh.timeout = 60
        rundeck.server.uuid = ${cfg.serverUUID}
        EOF

        cat > ${cfg.configDir}/realm.properties <<EOF
        ${cfg.adminUser}:${cfg.adminPassword},user,admin
        EOF

        cat > ${cfg.configDir}/jaas-loginmodule.conf <<EOF
        RDpropertyfilelogin {
          org.eclipse.jetty.jaas.spi.PropertyFileLoginModule required
          debug="true"
          file="/etc/rundeck/realm.properties";
        };
        EOF

        cat > ${cfg.configDir}/log4j2.properties <<EOF
        status = info
        name = RundeckPro

        appender.console.type = Console
        appender.console.name = STDOUT
        appender.console.layout.type = PatternLayout
        appender.console.layout.pattern = %d{DEFAULT} %-5p %c{1} - %m%n

        appender.file.type = RollingFile
        appender.file.name = FILE
        appender.file.fileName = ${cfg.dataDir}/logs/rundeck.log
        appender.file.filePattern = ${cfg.dataDir}/logs/rundeck.%d{yyyy-MM-dd}.log
        appender.file.layout.type = PatternLayout
        appender.file.layout.pattern = %d{DEFAULT} [%t] %-5p %c{1} - %m%n
        appender.file.policies.type = Policies
        appender.file.policies.time.type = TimeBasedTriggeringPolicy
        appender.file.policies.time.interval = 1
        appender.file.policies.time.modulate = true

        rootLogger.level = info
        rootLogger.appenderRef.stdout.ref = STDOUT
        rootLogger.appenderRef.file.ref = FILE

        logger.hibernate.name = org.hibernate
        logger.hibernate.level = ERROR
        EOF

        chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir} ${cfg.configDir}
        chmod -R u=rwX,g=rX,o= ${cfg.dataDir} ${cfg.configDir}
      '';
    };

    networking.firewall.allowedTCPPorts = [ 4440 ];
  };
}

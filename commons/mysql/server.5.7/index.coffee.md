
# Mysql Server

Install MySQL Server 5.7 community.

    module.exports =
      use:
        iptables: module: 'masson/core/iptables'
      configure:
        'masson/commons/mysql/server.5.7/configure'
      commands:
        'install': [
          'masson/commons/mysql/server.5.7/install'
          'masson/commons/mysql/server.5.7/check'
        ]
        'start':
          'masson/commons/mysql/server/start'
        'stop':
          'masson/commons/mysql/server/stop'

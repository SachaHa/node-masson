
# Bind server

Install and configure [named](http://linux.die.net/man/8/named), a 
Domain Name System (DNS) server, part of the BIND 9 distribution f
rom ISC.

    module.exports =
      use:
        iptables: implicit: true, module: 'masson/core/iptables'
        yum: module: 'masson/core/yum'
      configure:
        'masson/core/bind_server/configure'
      commands:
        'install': [
          'masson/core/bind_server/install'
          'masson/core/bind_server/start'
        ]
        'start':
          'masson/core/bind_server/start'
        'stop':
          'masson/core/bind_server/stop'

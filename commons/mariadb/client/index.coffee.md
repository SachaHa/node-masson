
# MariaDB

Install the MariaDB command-line tool.

    module.exports =
      commands:
        'install': header: 'MariaDB Client', handler: (options) ->

## Package

Install the Mysql client.

          @service
            if_os: name: ['redhat','centos'], version: '7'
            name: 'mariadb'
          @service
            if_os: name: ['redhat','centos'], version: '6'
            name: 'mysql'

## Connector

Install the Mysql JDBC driver.

          @service
            header: 'Connector'
            name: 'mysql-connector-java'

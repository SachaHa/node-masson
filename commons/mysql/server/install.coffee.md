
# MySQL Server Install

    module.exports = header: 'MySQL Server Install', handler: ->
      {iptables} = @config
      options = @config.mysql.server

## IPTables

| Service           | Port | Proto | Parameter |
|-------------------|------|-------|-----------|
| MySQL             | 3306 | tcp   | -         |


IPTables rules are only inserted if the parameter "iptables.action" is set to
"start" (default value).

      @tools.iptables
        header: 'IPTables'
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: options.my_cnf['mysqld']['port'], protocol: 'tcp', state: 'NEW', comment: "MySQL" }
        ]
        if: @has_service('masson/core/iptables') and iptables.action is 'start'

## User & groups

By default the "mariadb-server/mysql-server" packages create the following entry:

```bash
cat /etc/passwd | grep mysql
mysql:x:27:27:MariaDB Server:/var/lib/mysql:/sbin/nologin
```
Actions present to be able to change uid/gid:
Note: Be careful if using different name thans 'mysql:mysql'
User/group are hard coded in some of mariadb/mysql package scripts.

      @call header: 'Users & Groups', handler: ->
        @system.group options.group
        @system.user options.user

## Yum Repositories

Upload the YUM repository definitions files present in 
"options.copy" to the yum repository directory 
in "/etc/yum.repos.d"

      @tools.repo
        if: options.repo?
        header: 'Repo'
        source: options.repo.source
        update: options.repo.update
        target: '/etc/yum.repos.d/mysql.repo'
        clean: 'mysql*'

## Package

Install the MySQL database server. Secure the temporary directory. Install MariaDB
Package on Centos/Redhat 7 OS.

      @call header: 'Package', ->
        @service.install
          name: 'mysql-community-release'
          if_exec: 'yum info mysql-community-release'
        @system.tmpfs
          header: 'TempFS pid'
          if_os: name: ['centos', 'redhat', 'oracle'], version: '7'
          mount: "#{path.dirname options.my_cnf['mysqld']['pid-file']}"
          name: 'mysqld'
          perm: '0750'
          uid: options.user.name
          gid: options.group.name
        @service
          header: 'Install'
          name: 'mysql-community-server'
          if_exec: 'yum info mysql-community-server'
          startup: true
          chk_name: 'mysqld'
          srv_name: 'mysqld'
          action: 'start'
        @service
          header: 'Install'
          name: 'mysql-server'
          if_exec: 'yum info mysql-server'
          startup: true
          chk_name: 'mysqld'
          srv_name: 'mysqld'
          action: 'start'

## Configuration
Write /etc/my.cnf configuration file.

      @file.ini
        target: '/etc/my.cnf'
        content: options.my_cnf
        stringify: misc.ini.stringify_single_key
        merge: false
        backup: true

## Mysql <5.7 Secure Installation

This program enables you to improve the security of your MySQL installation in 
the following ways:

* Set a password for root accounts.
* Remove root accounts that are accessible from outside the local host.
* Remove anonymous-user accounts.
* Remove the test database (which by default can be accessed by all users, 
  even anonymous users), and privileges that permit anyone to access databases 
  with names that start with test_.

      @call
        header: 'Secure'
        if_exec: 'echo "show databases" | mysql -uroot'
      , (options, callback) ->
        options.ssh.shell (err, stream) =>
          return callback err if err
          stream.write '/usr/bin/mysql_secure_installation\n'
          stream.on 'data', (data, extended) =>
            data = data.toString()
            switch
              when /Enter current password for root/.test data
                options.log data
                stream.write "#{options.current_password}\n"
              when /Change the root password/.test data
                options.log data
                stream.write "y\n"
              when /Set root password/.test data
                options.log data
                stream.write "y\n"
              when /New password/.test(data) or /Re-enter new password/.test(data)
                options.log data
                stream.write "#{options.password}\n"
              when /Remove anonymous users/.test data
                options.log data
                stream.write "y\n"
              when /Disallow root login remotely/.test data
                options.log data
                stream.write "y\n"
              when /Remove test database and access to it/.test data
                options.log data
                stream.write "y\n"
              when /Reload privilege tables now/.test data
                options.log data
                stream.write "y\n"
              when /All done/.test data
                options.log data
                stream.end 'exit\n'
          stream.on 'error', (err) ->
            callback err
          stream.on 'exit', =>
            @service.restart 'mysqld' unless err
            @then (err) -> callback err, true

## Mysql >5.7 Secure Temp Password

If this is the first run, grab the temporary password from the log.

      password = null
      @system.execute
        header: 'Temp Password'
        unless_exec: db.cmd
          engine: 'mysql'
          host: 'localhost'
          username: 'root'
          password: "#{options.password}"
        , "SHOW STATUS"
        cmd: "grep 'temporary password' /var/log/mysqld.log"
        shy: true
      , (err, status, stdout) ->
        throw err if err
        password = / ([^ ]+)$/.exec(stdout)[1].trim() if status

## Mysql >5.7 Secure Root Password

Now we open a shell to change the password. Note, we can not pass the query as 
a command argumet because it can not be run interractively.

      @call
        header: 'Root Password'
        if: -> password
      , (_, callback) ->
        _.ssh.shell (err, stream) =>
          return callback err if err
          cmd = db.cmd
            engine: 'mysql'
            host: 'localhost'
            username: 'root'
            password: password
          stream.write "#{cmd}\n"
          err = null
          called = 0
          stream.on 'data', (data, extended) =>
            data = data.toString()
            if /ERROR/.test data
              err = new Error /ERROR.*/.exec(data)[0]
              stream.write 'quit\n'
              stream.end 'exit\n'
              called = 3
            else if called is 0 and /mysql>/.test data
              stream.write "ALTER USER 'root'@'localhost' IDENTIFIED BY '#{options.password}';\n"
              called++
            else if called is 1 and /mysql>/.test data
              stream.write 'quit\n'
              called++
            else if called is 2
              stream.end 'exit\n'
              called++
          stream.on 'exit', ->
            callback err, true

      @system.execute
        header: 'External Root Access'
        if: options.root_host
        cmd: """
        function mysql_exec {
          read query
          mysql \
           -hlocalhost -P#{options.my_cnf['mysqld']['port']} \
           -uroot -p#{options.password} \
           -N -s -r -e \
           "$query" 2>/dev/null
        }
        exist=`mysql_exec <<SQL
        SELECT count(*) \
         FROM mysql.user \
         WHERE user = 'root' and host = '#{options.root_host}';
        SQL`
        [[ $exist -gt 0 ]] && exit 3
        mysql_exec <<SQL
        GRANT ALL PRIVILEGES \
         ON *.* TO 'root'@'#{options.root_host}' \
         IDENTIFIED BY '#{options.password}' \
         WITH GRANT OPTION;
        GRANT SUPER ON *.* TO 'root'@'#{options.root_host}';
        # UPDATE mysql.user \
        #  SET Grant_priv='Y', Super_priv='Y' \
        #  WHERE User='root' and Host='#{options.root_host}';
        FLUSH PRIVILEGES;
        SQL
        """
        code_skipped: 3

## Dependencies

    misc = require 'nikita/lib/misc'
    db = require 'nikita/lib/misc/db'
    path = require 'path'

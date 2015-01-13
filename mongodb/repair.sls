{#-
-*- ci-automatic-discovery: off -*-

Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.


Execute this state only when mongodb or the server crashed and it requires
a repair.
-#}

mongodb_repair:
  service:
    - dead
    - name: mongodb
  cmd:
    - run
    - name: /usr/bin/mongod --dbpath=/var/lib/mongodb --repair
    - require:
       - service: mongodb_repair

mongodb_repair_post:
  cmd:
    - run
    - name: chown -R mongodb:nogroup /var/lib/mongodb
    - require:
      - cmd: mongodb_repair
  service:
    - running
    - name: mongodb
    - require:
      - cmd: mongodb_repair_post

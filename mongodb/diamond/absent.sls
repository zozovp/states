{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}

diamond-pymongo:
  file:
    - absent
    - name: /usr/local/diamond/salt-mongodb-requirements.txt

diamond_mongodb:
  file:
    - absent
    - name: /etc/diamond/collectors/MongoDBCollector.conf

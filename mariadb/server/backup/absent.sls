{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}

/etc/cron.daily/backup-mysql:
  file:
    - absent

/usr/local/bin/backup-mysql:
  file:
    - absent

/usr/local/bin/backup-mysql-all:
  file:
    - absent

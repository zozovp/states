{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}
backup-openldap:
  file:
    - absent
    - name: /etc/cron.daily/backup-openldap

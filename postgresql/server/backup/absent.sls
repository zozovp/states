{#
 Remove Backup client for PostgreSQL
 #}
/etc/cron.daily/backup-postgresql:
  file:
    - absent

/usr/local/bin/backup-postgresql:
  file:
    - absent

/usr/local/bin/backup-postgresql-all:
  file:
    - absent

/usr/local/bin/backup-postgresql-copy:
  file:
    - absent

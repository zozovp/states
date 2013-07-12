{#
 Backup client for PostgreSQL
 #}
/etc/cron.daily/backup-postgresql:
  file:
    - absent

/usr/local/bin/backup-postgresql:
  file:
    - managed
    - user: root
    - group: root
    - mode: 500
    - template: jinja
    - source: salt://postgresql/server/backup/script.jinja2

/usr/local/bin/backup-postgresql-all:
  file:
    - managed
    - user: root
    - group: root
    - mode: 500
    - template: jinja
    - source: salt://postgresql/server/backup/dump_all.jinja2


/usr/local/bin/backup-postgresql-copy:
  file:
    - managed
    - user: root
    - group: root
    - mode: 500
    - template: jinja
    - source: salt://postgresql/server/backup/copy.jinja2

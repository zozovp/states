{#- Usage of this is governed by a license that can be found in doc/license.rst -#}

include:
  - bash
  - cron
  - backup.client

backup-openldap:
  file:
    - managed
    - name: /etc/cron.daily/backup-openldap
    - user: root
    - group: root
    - mode: 500
    - template: jinja
    - source: salt://openldap/backup/cron.jinja2
    - require:
      - pkg: cron
      - file: /usr/local/bin/backup-store
      - file: bash

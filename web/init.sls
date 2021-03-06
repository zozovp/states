{#- Usage of this is governed by a license that can be found in doc/license.rst -#}

web:
  user:
    - present
    - name: www-data
    - gid_from_name: True
    - system: True
    - fullname: www-data
    - shell: /usr/sbin/nologin
    - home: /var/www
    - createhome: True
    - password: "*"
    - enforce_password: True
    - require:
      - group: web
  file:
    - directory
    - name: /var/lib/deployments
    - user: www-data
    - group: www-data
    - mode: 775
    - require:
      - user: web
  group:
    - present
    - name: www-data

{#- ensure owner/mode of this dir #}
/var/www:
  file:
    - directory
    - user: www-data
    - group: www-data
    - mode: 775
    - require:
      - user: web

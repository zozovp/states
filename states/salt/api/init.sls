{#
 Setup a Salt API REST server.
 #}
include:
  - salt.master
  - git
  - nginx
  - diamond
  - nrpe
{% if pillar['salt_master']['ssl']|default(False) %}
  - ssl
{% endif %}

salt_api:
  group:
    - present

{# You need to set the password for each of those users #}
{% for user in pillar['salt_master']['external_auth']['pam'] %}
user_{{ user }}:
  user:
    - present
    - groups:
      - salt_api
    - home: /home/{{ user }}
    - shell: /bin/false
    - require:
      - group: salt_api
{% endfor %}

/etc/salt/master.d/ui.conf:
  file:
    - managed
    - template: jinja
    - source: salt://salt/api/config.jinja2
    - user: root
    - group: root
    - mode: 400

salt-api:
  pkg:
    - installed
    - require:
      - pkg: salt-master
      - pip: salt-api
  pip:
    - installed
    - name: cherrypy
  file:
    - managed
    - name: /etc/init/salt-api.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - source: salt://salt/api/upstart.jinja2
  service:
    - running
    - watch:
      - file: salt-api
      - pip: salt-api
      - git: salt-ui
      - file: /etc/salt/master.d/ui.conf

salt-ui:
  git:
    - latest
    - rev: {{ pillar['salt_master']['ui'] }}
    - name: git://github.com/saltstack/salt-ui.git
    - target: /usr/local/salt-ui/
  file:
    - managed
    - name: /etc/nginx/conf.d/salt.conf
    - template: jinja
    - source: salt://salt/api/nginx.jinja2
    - user: www-data
    - group: www-data
    - mode: 440
    - require:
      - pkg: nginx

/etc/nagios/nrpe.d/salt-api.cfg:
  file:
    - managed
    - template: jinja
    - user: nagios
    - group: nagios
    - mode: 440
    - source: salt://salt/api/nrpe.jinja2
    - require:
      - pkg: nagios-nrpe-server

salt_api_diamond_resources:
  file:
    - accumulated
    - name: processes
    - filename: /etc/diamond/collectors/ProcessResourcesCollector.conf
    - require_in:
      - file: /etc/diamond/collectors/ProcessResourcesCollector.conf
    - text:
      - |
        [[salt.api]]
        name = ^salt\-api

extend:
  nagios-nrpe-server:
    service:
      - watch:
        - file: /etc/nagios/nrpe.d/salt-api.cfg
  nginx:
    service:
      - watch:
        - file: salt-ui
{% if pillar['salt_master']['ssl']|default(False) %}
        - cmd: /etc/ssl/{{ pillar['salt_master']['ssl'] }}/chained_ca.crt
        - module: /etc/ssl/{{ pillar['salt_master']['ssl'] }}/server.pem
        - file: /etc/ssl/{{ pillar['salt_master']['ssl'] }}/ca.crt
{% endif %}
  salt-master:
    service:
      - watch:
        - file: /etc/salt/master.d/ui.conf

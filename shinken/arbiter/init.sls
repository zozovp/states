{#-
Copyright (c) 2013, Bruno Clermont
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Author: Bruno Clermont <patate@fastmail.cn>
Maintainer: Bruno Clermont <patate@fastmail.cn>

State for Shinken Arbiter.

A daemon reads the configuration, divides it into parts
(N schedulers = N parts), and distributes them to the appropriate Shinken
daemons. Additionally, it manages the high availability features: if a
particular daemon dies, it re-routes the configuration managed by this failed
daemon to the configured spare. Finally, it can receive input from users (such
as external commands from nagios.cmd) or passive check results and routes them
to the appropriate daemon. Passive check results are forwarded to the Scheduler
responsible for the check. There can only be one active arbiter with other
arbiters acting as hot standby spares in the architecture.
-#}
include:
  - hostname
  - rsyslog
  - shinken
{%- if salt['pillar.get']('shinken:ssl', False) %}
  - ssl
{%- endif %}
  - ssmtp

{#{% if 'arbiter' in pillar['shinken']['roles'] %}#}
{#    {% if pillar['shinken']['arbiter']['use_mongodb'] %}#}
{#  - mongodb#}
{#    {% endif %}#}
{#{% endif %}#}

{% set configs = ('architecture', 'infra') %}

shinken-init:
  cmd:
    - run
    - user: shinken
    - name: /usr/local/shinken/bin/python /usr/bin/shinken --init
    - unless: test -f /var/lib/shinken/.shinken.ini
    - require:
      - module: shinken

shinken-arbiter:
  file:
    - managed
    - name: /etc/init/shinken-arbiter.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - source: salt://shinken/arbiter/upstart.jinja2
    - require:
      - pkg: ssmtp
      - host: hostname
      - module: shinken
  service:
    - running
    - enable: True
    - order: 50
    - require:
      - file: /var/log/shinken
      - file: /var/lib/shinken
      - file: /etc/shinken/objects
      - pkg: ssmtp
{#- does not use PID, no need to manage #}
    - watch:
      - user: shinken
      - module: shinken
      - file: shinken
      - file: shinken-arbiter
      - file: /etc/shinken/arbiter.conf
    {% for config in configs %}
      - file: /etc/shinken/{{ config }}.conf
    {% endfor %}

{%- for module in ('auth-cfg-password', 'booster-nrpe', 'graphite', 'nsca', 'pickle-retention-file-generic', 'sqlitedb', 'syslog-sink', 'ui-graphite', 'webui') %}
{{ module }}:
  cmd:
    - run
    - user: shinken
    - name: /usr/local/shinken/bin/python /usr/bin/shinken install {{ module }}
    - unless: /usr/local/shinken/bin/python /usr/bin/shinken inventory | grep {{ module }}
    - require:
      - module: shinken
      - cmd: shinken-init
{%- endfor %}

/etc/shinken/arbiter.conf:
  file:
    - managed
    - template: jinja
    - user: shinken
    - group: shinken
    - mode: 440
    - source: salt://shinken/arbiter/config.jinja2
    - context:
      configs:
{% for config in configs %}
        - {{ config }}
{% endfor %}
    - require:
      - file: /etc/shinken
      - user: shinken
{%- if salt['pillar.get']('shinken:ssl', False) %}
      - cmd: ssl_cert_and_key_for_{{ pillar['shinken']['ssl'] }}
{% endif %}

/etc/shinken/objects:
  file:
    - directory
    - template: jinja
    - user: shinken
    - group: shinken
    - mode: 550
    - require:
      - file: /etc/shinken
      - user: shinken

{% for config in configs %}
/etc/shinken/{{ config }}.conf:
  file:
    - managed
    - template: jinja
    - user: shinken
    - group: shinken
    - mode: 440
    - source: salt://shinken/{{ config }}.jinja2
    - require:
      - file: /etc/shinken
      - user: shinken
{% endfor %}

{% from 'rsyslog/upstart.sls' import manage_upstart_log with context %}
{{ manage_upstart_log('shinken-arbiter') }}

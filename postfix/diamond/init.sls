{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}
{%- from 'upstart/rsyslog.jinja2' import manage_upstart_log with context -%}
include:
{%- if salt['pillar.get']('postfix:spam_filter', False) %}
  - amavis.diamond
    {%- if salt['pillar.get']('amavis:check_virus', True) %}
  - clamav.diamond
    {%- endif %}
{%- endif %}
  - diamond
  - postfix
  - rsyslog
  - local

postfix_diamond_collector:
  file:
    - managed
    - name: /etc/diamond/collectors/PostfixCollector.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - source: salt://postfix/diamond/config.jinja2
    - require:
      - file: /etc/diamond/collectors
    - watch_in:
      - service: diamond

postfix_diamond_resources:
  file:
    - accumulated
    - name: processes
    - filename: /etc/diamond/collectors/ProcessResourcesCollector.conf
    - require_in:
      - file: /etc/diamond/collectors/ProcessResourcesCollector.conf
    - text:
      - |
        [[postfix]]
        exe = ^\/usr\/lib\/postfix\/master$
        cmdline = ^trivial-rewrite, ^tlsmgr, ^smtp -n amavisfeed, ^smtpd -n smtp, ^smtpd -n.* -t inet, ^qmgr -l -t fifo -u, ^proxymap -t unix -u, ^pickup -l -t fifo -u -c, ^lmtp -t unix -u -c, ^cleanup -z -t unix -u -c, ^anvil -l -t unix -u -c,

postfix_diamond_queue_length:
  file:
    - managed
    - name: /usr/local/diamond/share/diamond/user_scripts/postfix_queue_length.sh
    - template: jinja
    - user: root
    - group: root
    - mode: 550
    - source: salt://postfix/diamond/queue_length.jinja2
    - require:
      - module: diamond
      - file: diamond.conf

/var/log/mail.log:
  file:
    - managed
    - user: syslog
    - group: adm
    - mode: 640
    - require:
      - pkg: rsyslog
    - require_in:
      - service: rsyslog

/etc/rsyslog.d/postfix_stats.conf:
  file:
    - managed
    - user: root
    - group: root
    - mode: 440
    - source: salt://postfix/diamond/rsyslog.jinja2
    - template: jinja
    - require:
      - pkg: rsyslog
    - watch_in:
      - service: rsyslog

postfix_stats-requirements:
  file:
    - managed
    - name: /usr/local/diamond/salt-postfix-requirements.txt
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - source: salt://postfix/diamond/requirements.jinja2
    - require:
      - virtualenv: diamond

postfix_stats:
  service:
    - running
    - watch:
      - file: postfix_stats
      - module: postfix_stats
  file:
    - managed
    - name: /etc/init/postfix_stats.conf
    - source: salt://postfix/diamond/upstart.jinja2
    - template: jinja
    - require:
      - module: postfix_stats
      - file: /var/log/mail.log
      - file: /etc/rsyslog.d/postfix_stats.conf
  module:
    - wait
    - name: pip.install
    - upgrade: True
    - bin_env: /usr/local/diamond
    - requirements: /usr/local/diamond/salt-postfix-requirements.txt
    - require:
      - virtualenv: diamond
    - watch:
      - file: postfix_stats-requirements
    - watch_in:
      - service: diamond

{{ manage_upstart_log('postfix_stats') }}

extend:
  diamond:
    service:
      - require:
        - service: rsyslog
        - service: postfix
      {#- make sure postfix_stat service runs before diamond postfix collector
          which gets data from it #}
        - service: postfix_stats

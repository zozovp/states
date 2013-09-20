{#-
Copyright (c) 2013, <BRUNO CLERMONT>
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

Author: Bruno Clermont patate@fastmail.cn
Maintainer: Hung Nguyen Viet hvnsweeting@gmail.com
 
 Nagios NRPE check for PostgreSQL Server
-#}
{% set version="9.2" %}

include:
  - nrpe
  - postgresql.nrpe
  - postgresql.common.user
  - apt.nrpe
  - rsyslog.nrpe
{% if salt['pillar.get']('postgresql:ssl', False) %}
  - ssl.nrpe
{% endif %}

/etc/nagios/nrpe.d/postgresql-monitoring.cfg:
  file:
    - managed
    - template: jinja
    - user: nagios
    - group: nagios
    - mode: 440
    - source: salt://postgresql/nrpe.jinja2
    - require:
      - pkg: nagios-nrpe-server
    - context:
      deployment: monitoring
      version: {{ version }}
      password: {{ salt['password.pillar']('postgresql:monitoring:password') }}

/etc/nagios/nrpe.d/postgresql.cfg:
  file:
    - managed
    - template: jinja
    - user: nagios
    - group: nagios
    - mode: 440
    - source: salt://postgresql/common/nrpe/config.jinja2
    - require:
      - pkg: nagios-nrpe-server
    - context:
      version: {{ version }}

{%- set check_pg_version = "2.20.1" %}
check_postgres:
  archive:
    - extracted
    - name: /usr/local
    - source: http://bucardo.org/downloads/check_postgres.tar.gz
    - source_hash: md5=58b949ab92c7bfc7dab7914e8ecb76b3
    - archive_format: tar
    - tar_options: z
    - if_missing: /usr/local/check_postgres-{{ check_pg_version }}
    - require:
      - file: /usr/local
  file:
    - symlink
    - target: /usr/local/check_postgres-{{ check_pg_version }}/check_postgres.pl
    - name: /usr/lib/nagios/plugins/check_postgres
    - require:
      - pkg: nagios-nrpe-server
      - archive: check_postgres

extend:
  nagios-nrpe-server:
    service:
      - watch:
        - file: /etc/nagios/nrpe.d/postgresql.cfg
        - file: /etc/nagios/nrpe.d/postgresql-monitoring.cfg
      - require:
        - postgres_database: postgresql_monitoring

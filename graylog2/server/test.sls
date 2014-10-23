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
-#}
{%- from 'cron/test.sls' import test_cron with context %}
include:
  - graylog2.server
  - graylog2.server.diamond
  - graylog2.server.nrpe
  - graylog2.server.backup
  - graylog2.server.backup.nrpe

{#- Graylog2 requires a running Elasticsearch server to work
  properly. Check will definitively fail. #}

graylog2_log_one_msg:
  cmd:
    - run
    - name: logger test
    - require:
      - service: graylog2-server

{%- call test_cron() %}
- sls: graylog2.server
- sls: graylog2.server.backup
{%- endcall %}

test:
  monitoring:
    - run_all_checks
    - wait: 60
    - order: last
    - exclude:
      - graylog2_server-es_cluster
      - graylog2_server-es_port_transport
      - graylog2_incoming_logs
      - graylog2_api_port
      - graylog2_api

test_import_general_syslog_udp_input:
  cmd:
    - script
    - name: import_general_syslog_udp_input graylog2-0-20
    - source: salt://graylog2/server/import_general_syslog_udp_input.py
    - require:
      - sls: graylog2.server

test_log_generator:
  script:
    - run
    - name: /usr/local/graylog2-server-0.20.6/bin/log_generator
    - template: jinja
    - source: salt://graylog2/server/log_generator.py
    - require:
      - sls: graylog2.server

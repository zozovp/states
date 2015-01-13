{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}
{%- from 'cron/test.jinja2' import test_cron with context %}
{%- from 'diamond/macro.jinja2' import diamond_process_test with context %}
include:
  - doc
  - rabbitmq
  - rabbitmq.diamond
  - rabbitmq.nrpe

{%- call test_cron() %}
- sls: rabbitmq
- sls: rabbitmq.diamond
- sls: rabbitmq.nrpe
{%- endcall %}

test:
  monitoring:
    - run_all_checks
    - order: last
    - require:
      - cmd: test_crons
  diamond:
    - test
    - map:
        ProcessResources:
    {{ diamond_process_test('rabbitmq') }}
        RabbitMQ:
          rabbitmq.health.fd_used: False
          rabbitmq.health.fd_total: False
          rabbitmq.health.mem_used: False
          rabbitmq.health.mem_limit: False
          rabbitmq.health.sockets_used: False
          rabbitmq.health.sockets_total: False
          rabbitmq.health.disk_free_limit: False
          rabbitmq.health.disk_free: False
          rabbitmq.health.proc_used: False
          rabbitmq.health.proc_total: False
          rabbitmq.object_totals.connections: False
          rabbitmq.object_totals.channels: False
          rabbitmq.object_totals.queues: False
          rabbitmq.object_totals.consumers: False
          rabbitmq.object_totals.exchanges: False
    - require:
      - sls: rabbitmq
      - sls: rabbitmq.diamond
  qa:
    - test
    - name: rabbitmq
    - pillar_doc: {{ opts['cachedir'] }}/doc/output
    - require:
      - monitoring: test
      - cmd: doc

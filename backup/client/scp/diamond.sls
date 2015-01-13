{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}
include:
  - backup.diamond
{%- set address = salt['pillar.get']('backup_server:address') %}
{%- if address in grains['ipv4'] or
       address in ('localhost', grains['host']) %}
  {#- If backup_server address set to localhost (mainly in CI testing), install backup.server first #}
  - backup.server.diamond
{%- endif %}

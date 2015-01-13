{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}
{%- from 'nrpe/passive.jinja2' import passive_absent with context %}
{{ passive_absent('backup.server') }}

/usr/local/bin/check_backups.py:
  file:
    - absent

/usr/lib/nagios/plugins/check_backups.py:
  file:
    - absent

/etc/sudoers.d/nrpe_backups:
  file:
    - absent


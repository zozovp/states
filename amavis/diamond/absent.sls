{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

-#}
/etc/diamond/collectors/AmavisCollector.conf:
  file:
    - absent
    {#- specified a small order, try to make this run before amavis.absent run,
        otherwise, amavis collector will notify error due to not found amavis-agent #}
    - order: 10

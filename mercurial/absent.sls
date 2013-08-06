mercurial:
  file:
    - absent
    - name: {{ opts['cachedir'] }}/salt-mercurial-requirements.txt
{%- if salt['cmd.has_exec']('pip') %}
  pip:
    - removed
    - order: 1
{%- endif %}

{#
 Install Salt Minion (client)
 #}

include:
  - apt

{# it's mandatory to remove this file if the master is changed #}
salt_minion_master_key:
  module:
    - wait
    - name: file.remove
    - path: /etc/salt/pki/minion/minion_master.pub
    - watch:
      - file: salt-minion

salt-minion:
  apt_repository:
    - ubuntu_ppa
    - user: saltstack
    - name: salt
    - key_id: 0E27C0A6
  file:
    - managed
    - template: jinja
    - name: /etc/salt/minion
    - user: root
    - group: root
    - mode: 440
    - source: salt://salt/minion/config.jinja2
    - require:
      - pkg: salt-minion
  pkg:
    - latest
    - names:
      - salt-minion
      - python-software-properties
      - debconf-utils
{% if grains['virtual'] != 'openvzve' %}
      - pciutils
      - dmidecode
{% endif %}
    - require:
      - apt_repository: salt-minion
      - cmd: apt_sources
  service:
    - running
    - enable: True
    - watch:
      - pkg: salt-minion
      - file: salt-minion
      - module: salt_minion_master_key

{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.
-#}
{%- set ca_name = salt['pillar.get']('openvpn:ca:name') %}
{%- set key_size = salt['pillar.get']('openvpn:dhparam:key_size', 2048) %}

include:
  - apt
  - openvpn

openvpn_ca:
  module:
    - run
    - name: tls.create_ca
    - ca_name: {{ ca_name }}
    - bits: {{ salt['pillar.get']('openvpn:ca:bits') }}
    - days: {{ salt['pillar.get']('openvpn:ca:days') }}
    - CN: {{ salt['pillar.get']('openvpn:ca:common_name') }}
    - C: {{ salt['pillar.get']('openvpn:ca:country') }}
    - ST: {{ salt['pillar.get']('openvpn:ca:state') }}
    - L: {{ salt['pillar.get']('openvpn:ca:locality') }}
    - O: {{ salt['pillar.get']('openvpn:ca:organization') }}
    - OU: {{ salt['pillar.get']('openvpn:ca:organizational_unit') }}
    - emailAddress: {{ salt['pillar.get']('openvpn:ca:email') }}
  file:
    - copy
    - name: /etc/openvpn/ca.crt
    - source: /etc/pki/{{ ca_name }}/{{ ca_name }}_ca_cert.crt
    - require:
      - module: openvpn_ca

openvpn_dh:
  cmd:
    - run
    - name: openssl dhparam -out /etc/openvpn/dh{{ key_size}}.pem {{ key_size }}
    - unless: test -f /etc/openvpn/dh{{ key_size}}.pem

{%- for instance in salt['pillar.get']('openvpn:servers') %}
openvpn_server_csr_{{ instance }}:
  module:
    - run
    - name: tls.create_csr
    - ca_name: {{ ca_name }}
    - CN: server
    - require:
      - module: openvpn_ca

openvpn_server_cert_{{ instance }}:
  module:
    - run
    - name: tls.create_ca_signed_cert
    - ca_name: {{ ca_name }}
    - CN: server
    - extensions:
        basicConstraints:
          critical: False
          options: 'CA:FALSE'
        keyUsage:
          critical: False
          options: 'Digital Signature, Key Encipherment'
        extendedKeyUsage:
          critical: False
          options: 'serverAuth'
    - require:
      - module: openvpn_server_csr_{{ instance }}

openvpn_client_csr_{{ instance }}:
  module:
    - run
    - name: tls.create_csr
    - ca_name: {{ ca_name }}
    - CN: client
    - require:
      - module: openvpn_ca

openvpn_client_cert_{{ instance }}:
  module:
    - run
    - name: tls.create_ca_signed_cert
    - ca_name: {{ ca_name }}
    - CN: client
    - extensions:
        basicConstraints:
          critical: False
          options: 'CA:FALSE'
        keyUsage:
          critical: False
          options: 'Digital Signature'
        extendedKeyUsage:
          critical: False
          options: 'clientAuth'
    - require:
      - module: openvpn_client_csr_{{ instance }}

/etc/openvpn/{{ instance }}:
  file:
    - directory
    - user: root
    - group: root
    - mode: 400
    - require:
      - pkg: openvpn

openvpn_{{ instance }}:
  cmd:
    - run
    - name: mv /etc/pki/{{ ca_name }}/certs/* /etc/openvpn/{{ instance }}
    - require:
      - module: openvpn_server_cert_{{ instance }}
      - module: openvpn_client_cert_{{ instance }}
  file:
    - managed
    - name: /etc/openvpn/{{ instance }}.conf
    - source: salt://openvpn/tls/config.jinja2
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - context:
        instance: {{ instance }}
    - require:
      - file: /etc/openvpn/{{ instance }}

start_openvpn_{{ instance }}:
  cmd:
    - run
    - name: service openvpn start {{ instance }}
    - watch:
      - file: openvpn_{{ instance }}
      - file: /etc/default/openvpn
{%- endfor %}

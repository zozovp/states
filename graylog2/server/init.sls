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
 Maintainer: Bruno Clermont patate@fastmail.cn

 Install a Graylog2 logging server backend
 -#}
include:
  - graylog2
{% if grains['osrelease']|float < 12.04 %}
  - java.6
{% else %}
  - java.7
{% endif %}
  - mongodb
  - apt
  - local

{# TODO: set Email output plugin settings straight into MongoDB from salt #}
{# TODO: run graylog2 server as a non-root user #}

{% set version = '0.11.0' %}
{% set checksum = 'md5=135c9eb384a03839e6f2eca82fd03502' %}
{% set server_root_dir = '/usr/local/graylog2-server-' + version %}

graylog2-server_upstart:
  file:
    - managed
    - name: /etc/init/graylog2-server.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 600
    - source: salt://graylog2/server/upstart.jinja2
    - context:
      version: {{ version }}

{#graylog2-server_logrotate:#}
{#  file:#}
{#    - managed#}
{#    - name: /etc/logrotate.d/graylog2-server#}
{#    - template: jinja#}
{#    - user: root#}
{#    - group: root#}
{#    - mode: 600#}
{#    - source: salt://graylog2/server/logrotate.jinja2#}

{# For cluster using, all node's data should be explicit: http,master,data,port and/or name #}
/etc/graylog2-elasticsearch.yml:
  file:
    - managed
    - source: salt://elasticsearch/config.jinja2
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - context:
      master: 'false'
      data: 'false'
      origin_state: graylog2.server

graylog2-server:
  archive:
    - extracted
    - name: /usr/local/
{%- if 'files_archive' in pillar %}
    - source: {{ pillar['files_archive'] }}/mirror/graylog2-server-{{ version }}.tar.gz
{%- else %}
    - source: http://download.graylog2.org/graylog2-server/graylog2-server-{{ version }}.tar.gz
{%- endif %}
    - source_hash: {{ checksum }}
    - archive_format: tar
    - tar_options: z
    - if_missing: {{ server_root_dir }}
    - require:
      - file: /usr/local
  file:
    - managed
    - name: /etc/graylog2.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 440
    - source: salt://graylog2/server/config.jinja2
    - context:
      version: {{ version }}
{#
 IMPORTANT:
 graylog2-server need to be restarted after any change in
 mail output plugin settings.
#}
  service:
    - running
    - enable: True
    - order: 50
    - watch:
      - file: graylog2-server_upstart
      - pkg: openjdk_jre_headless
      - file: graylog2-server
      - file: /etc/graylog2-elasticsearch.yml
      - archive: graylog2-server
      - cmd: graylog2_email_output_plugin
      - file: graylog2_sentry_output_plugin
      - file: graylog2_sentry_transport_plugin
    - require:
      - file: /var/log/graylog2
      - service: mongodb

graylog2_email_output_plugin:
  cmd:
    - run
    - name: java -jar graylog2-server.jar --install-plugin email_output --plugin-version 0.10.0
    - cwd: {{ server_root_dir }}
    - unless: test -e {{ server_root_dir }}/plugin/outputs/org.graylog2.emailoutput.output.EmailOutput_gl2plugin.jar
    - require:
      - file: graylog2-server
      - file: /etc/graylog2-elasticsearch.yml
      - archive: graylog2-server
      - pkg: openjdk_jre_headless
      - service: mongodb

graylog2_sentry_output_plugin:
  file:
    - managed
    - name: {{ server_root_dir }}/plugin/outputs/com.bitflippers.sentryoutput.output.SentryOutput_gl2plugin.jar
{% if 'files_archive' in pillar %}
    - source: {{ pillar['files_archive'] }}/mirror/graylog2-plugin-sentry-output-0.11.jar
{% else %}
    - source: http://archive.robotinfra.com/mirror/graylog2-plugin-sentry-output-0.11.jar
{% endif %}
    - source_hash: md5=9f8305a17af8bf6ab80dcab252489ec6
    - require:
      - file: graylog2-server
      - archive: graylog2-server
    - user: root
    - group: root
    - mode: 440

graylog2_sentry_transport_plugin:
  file:
    - managed
    - name: {{ server_root_dir }}/plugin/transports/com.bitflippers.sentrytransport.transport.SentryTransport_gl2plugin.jar
{% if 'files_archive' in pillar %}
    - source: {{ pillar['files_archive'] }}/mirror/graylog2-plugin-sentry-transport-0.11-1.jar
{% else %}
    - source: http://archive.robotinfra.com/mirror/graylog2-plugin-sentry-transport-0.11-1.jar
{% endif %}
    - source_hash: md5=7b7982643577aed239efaea62e78104a
    - require:
      - file: graylog2-server
      - archive: graylog2-server
    - user: root
    - group: root
    - mode: 440

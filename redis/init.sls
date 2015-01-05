{#-
Use of this source code is governed by a BSD license that can be found
in the doc/license.rst file.

Author: Viet Hung Nguyen <hvn@robotinfra.com>
Maintainer: Van Diep Pham <favadi@robotinfra.com>
-#}
{%- from 'macros.jinja2' import manage_pid with context %}

{%- set redis_version = "2.8.4" %}
{%- set jemalloc_version = "3.4.1" %}

{%- set redis_sub_version = "2:{0}-1chl1~{1}1".format(redis_version, grains['lsb_distrib_codename']) %}
{%- set jemalloc_sub_version = "{0}-1chl1~{1}1".format(jemalloc_version, grains['lsb_distrib_codename']) %}

{%- set jemalloc = "libjemalloc1_{0}-1chl1~{1}1_{2}.deb".format(jemalloc_version, grains['lsb_distrib_codename'], grains['debian_arch']) %}
{%- set filename = "redis-server_{0}-1chl1~{1}1_{2}.deb".format(redis_version, grains['lsb_distrib_codename'], grains['debian_arch']) %}
{%- set redistools = "redis-tools_{0}-1chl1~{1}1_{2}.deb".format(redis_version, grains['lsb_distrib_codename'], grains['debian_arch']) %}

redis:
  file:
    - managed
    - template: jinja
    - source: salt://redis/config.jinja2
    - name: /etc/redis/redis.conf
    - user: redis
    - group: redis
    - mode: 440
    - makedirs: True
    - require:
      - pkg: redis
  service:
    - running
    - enable: True
    - name: redis-server
    - order: 50
    - watch:
      - file: redis
      - pkg: redis
      - user: redis
  pkg:
    - installed
    - sources:
{%- if salt['pillar.get']('files_archive', False) %}
      - libjemalloc1: {{ salt['pillar.get']('files_archive', False)|replace('file://', '')|replace('https://', 'http://') }}/mirror/{{ jemalloc }}
      - redis-server: {{ salt['pillar.get']('files_archive', False)|replace('file://', '')|replace('https://', 'http://') }}/mirror/{{ filename }}
      - redis-tools: {{ salt['pillar.get']('files_archive', False)|replace('file://', '')|replace('https://', 'http://') }}/mirror/{{ redistools }}
{%- else %}
      - libjemalloc1: http://ppa.launchpad.net/chris-lea/redis-server/ubuntu/pool/main/j/jemalloc/{{ jemalloc }}
      - redis-server: http://ppa.launchpad.net/chris-lea/redis-server/ubuntu/pool/main/r/redis/{{ filename }}
      - redis-tools: http://ppa.launchpad.net/chris-lea/redis-server/ubuntu/pool/main/r/redis/{{ redistools }}
{%- endif %}
  user:
    - present
    - shell: /bin/false
    - require:
      - pkg: redis

{%- call manage_pid('/var/run/redis/redis-server.pid', 'redis', 'redis', 'redis-server') %}
- pkg: redis
{%- endcall %}

{%- if salt['pkg.version']('libjemalloc1') not in ('', jemalloc_sub_version) %}
jemalloc_old_version:
  pkg:
    - removed
    - name: libjemalloc1
    - require_in:
      - pkg: redis
{%- endif %}

{%- if salt['pkg.version']('redis-server') not in ('', redis_sub_version)  %}
redis_old_version:
  pkg:
    - removed
    - name: redis-server
    - require_in:
      - pkg: redis
{%- endif %}

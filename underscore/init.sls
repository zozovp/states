{#- Usage of this is governed by a license that can be found in doc/license.rst -#}

include:
  - apt

{%- from "os.jinja2" import os with context %}

libjs-underscore:
{%- if os.is_precise %}
  {%- set version = '1.4.2-1chl1~precise1' %}
  pkgrepo:
    - managed
  {%- set files_archive = salt['pillar.get']('files_archive', False) %}
  {%- if files_archive %}
    - name: deb {{ files_archive|replace('https://', 'http://') }}/mirror/underscore/1.4.2-1 {{ grains['lsb_distrib_codename'] }} main
    - key_url: salt://underscore/key.gpg
  {%- else %}
    - ppa: chris-lea/libjs-underscore
  {%- endif %}
    - file: /etc/apt/sources.list.d/chris-lea-libjs-underscore-{{ grains['oscodename'] }}.list
    - clean_file: True
    - require:
      - cmd: apt_sources
    - require_in:
      - pkg: libjs-underscore
{%- endif %}
  pkg:
    - installed
{%- if os.is_precise %}
    - version: {{ version }}
{%- endif %}
    - require:
      - cmd: apt_sources

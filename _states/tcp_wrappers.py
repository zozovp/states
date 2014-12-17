#-*- encoding: utf-8 -*-

# Copyright (c) 2013, Bruno Clermont
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""
tcp_wrappers state
manage part of content in hosts.allow and hosts.deny
"""

__author__ = 'Bruno Clermont'
__maintainer__ = 'Hung Nguyen Viet'
__email__ = 'hvn@robotinfra.com'

import logging

ALLOW_PATH = '/etc/hosts.allow'
DENY_PATH = '/etc/hosts.deny'
log = logging.getLogger(__name__)


def _process_args(name, type, service):
    ret = {'name': name, 'changes': {}, 'result': True, 'comment': ''}
    service_clients = "{0} : {1}".format(service, name)
    if type not in ('allow', 'deny'):
        ret['result'] = False
        ret['comment'] = 'Invalid type {0}'.format(type)
        path = None
    else:
        path = ALLOW_PATH if type == 'allow' else DENY_PATH
    return path, service_clients, ret


def present(name, type, service):
    '''
    Make sure that entry `service`:`name` is present in hosts.<`type`> file

    Example::

      192.168.32.12:
        tcp_wrappers:
          - present
          - type: allow
          - service: ftp

      3.3.3.3, 3.4.5.6:
        tcp_wrappers:
          - present
          - type: deny
          - service: http
    '''
    path, service_clients, ret = _process_args(name, type, service)
    if not ret['result']:
        return ret

    if __salt__['file.contains'](path, '{0}\n'.format(service_clients)):
        ret['result'] = True
        ret['comment'] = '{0} is already {1}'.format(service_clients, type)
    elif __opts__['test']:
        ret['result'] = None
        ret['comment'] = '{0} would have been {1}'.format(name, type)
    else:
        if __salt__['file.contains'](path, '{0} :'.format(service)):
            # TODO this will be changed to file.search in salt 0.17
            __salt__['file.psed'](path,
                                  '{0} : .*'.format(service),
                                  '{0}\n'.format(service_clients))
        else:
            __salt__['file.append'](path, service_clients)
        ret['changes'] = {service_clients: 'presented in {0}'.format(path)}
        ret['comment'] = '{0} is now {1} for {2}'.format(name, type, service)
        ret['result'] = True
    return ret


def absent(name, type, service):
    '''
    Make sure entry `service`:`name` does not exist in /etc/hosts.<`type`> file
    Example::

        123.32.12.12:
          tcp_wrappers:
            - absent
            - type: allow
            - service: ftp
    '''
    path, service_clients, ret = _process_args(name, type, service)
    if not ret['result']:
        return ret

    if not __salt__['file.contains'](path, service_clients):
        ret['result'] = True
        ret['comment'] = "{0} isn't already {1}".format(service_clients, type)
    elif __opts__['test']:
        ret['comment'] = '{0} would have been {1}'.format(name, type)
    else:
        lines = open(path).readlines()
        with open(path, 'w') as f:
            for line in lines:
                if line.strip() != service_clients:
                    f.write(line)
        ret['result'] = True
        ret['changes'] = {service_clients: 'removed from {0}'.format(path)}
        ret['comment'] = '{0} is not {1} anymore for {2}'.format(name, type,
                                                                 service)
    return ret

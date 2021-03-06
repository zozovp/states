#!/usr/local/nagios/bin/python2
# -*- coding: utf-8 -*-
# Use of this is governed by a license that can be found in doc/license.rst.

"""
nrpe check for Out Of Memory (OOM) message in syslog files.
"""

__author__ = 'Viet Hung Nguyen <hvn@robotinfra.com>'
__maintainer__ = 'Viet Hung Nguyen <hvn@robotinfra.com>'
__email__ = 'hvn@robotinfra.com'

import glob
import datetime

import nagiosplugin as nap
from pysc import nrpe


class OOM_Message(nap.Resource):
    def __init__(self, second_ago=3600):
        self.second_ago = second_ago

    def probe(self):
        found = self.number_of_oom_message()
        return [nap.Metric('oom_message', found, min=0, context='msg')]

    def is_near(self, log_msg):
        '''
        log_msg sample:
        Sep 25 07:59:28 integration kernel: [21152.249560] Out of memory:\
                Kill process 1108 (python) score 796 or sacrifice child
        '''
        this_year = str(datetime.datetime.now().year)
        time_in_log = ' '.join(log_msg.split()[:3])
        logtime = '{0} {1}'.format(this_year, time_in_log)
        lt = datetime.datetime.strptime(logtime, '%Y %b %d %H:%M:%S')
        now = datetime.datetime.now()
        if now < lt:
            # this means log_msg is created in last year, and now is new year
            return False
        else:
            delta = (now - lt).total_seconds()
            return delta <= self.second_ago

    def number_of_oom_message(self):
        cntr = 0
        syslog_files = glob.glob('/var/log/syslog*')
        for fn in syslog_files:
            with open(fn) as f:
                for line in f:
                    if 'Out of memory' in line and self.is_near(line):
                        cntr += 1
        return cntr


def check_oom(config):
    oom = (OOM_Message(config['seconds']) if config['seconds']
           else OOM_Message())
    return (oom, nap.ScalarContext('msg', '0:0', '0:0'))


if __name__ == "__main__":
    nrpe.check(check_oom, {'seconds': None})

#!/usr/local/nagios/bin/python
# -*- coding: utf-8 -*-

"""
Copyright (c) 2013, Bruno Clermont
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
"""

__author__ = 'Bruno Clermont'
__maintainer__ = 'Bruno Clermont'
__email__ = 'patate@fastmail.cn'

import argparse
import nagiosplugin
import sitemap
import sys
import bfs


class SiteMap(nagiosplugin.Resource):
    def __init__(self, sitemap):
        self.sitemap = sitemap

    def loc(self):
        loc = 0
        try:
            for i in sitemap.UrlSet.from_url(self.sitemap):
                loc += 1
            return loc
        except Exception as e:
            print 'SITEMAP WARNING - %s' % str(e)
            sys.exit(1)

    def probe(self):
        return [nagiosplugin.Metric('sitemap', self.loc(), context="sitemap")]


@nagiosplugin.guarded
@bfs.profile(log='nrpe.check_sitemap')
def main():
    argp = argparse.ArgumentParser(description=__doc__)
    argp.add_argument('-w', '--warning', metavar='RANGE', default='')
    argp.add_argument('-c', '--critical', metavar='RANGE', default='')
    argp.add_argument('-s', '--sitemap')
    args = argp.parse_args()
    check = nagiosplugin.Check(
            SiteMap(args.sitemap),
            nagiosplugin.ScalarContext('sitemap', args.warning, args.critical))
    check.main()

if __name__ == "__main__":
    main()

#!/usr/bin/env python2
'''
Script helps split the big stdout log file (which is generated by
integration.py) and search for specific message.
'''

__author__ = 'Hung Nguyen Viet'
__maintainer__ = 'Hung Nguyen Viet'
__email__ = 'hvn@robotinfra.com'

import argparse
import os
import shutil
import subprocess as spr
import logging
import tempfile
from contextlib import contextmanager


logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

SKIPS = [
    "OrderedDict",
    "Results of YAML rendering",
    "salt.utils.jinja",
]


def link_to_localpath(link):
    '''
    Turn
    https://ci.robotinfra.com/job/Chunks/292/artifact/Chunks-stdout.log.xz
    To
    /var/lib/jenkins/jobs/Chunks/builds/292/archive/Chunks-stdout.log.xz
    '''
    s = link.split('/job/')[1]
    s = '/builds/'.join(s.split('/', 1))
    return os.path.join('/var/lib/jenkins/jobs',
                        s.replace('/artifact/', '/archive/'))


def filtered_logs(logfile, slsname):
    '''
    a python version of sed '/Run top: slsname/Run top:/'
    This depends on the log of integration.py, change it accordingly if
    integration.py changes.
    '''
    begin_sls = 'Run top: {0}'.format(slsname)
    start_of_next_sls = 'Run top:'

    logger.debug("Looking for line with '%s' in file %s", begin_sls, logfile)
    foundsls = False
    with open(logfile) as origfile:
        write = False
        for line in origfile:
            if write and start_of_next_sls in line:
                # it is writing and meet the next sls log, stop
                break
            # a bit optimizing to not always strip line
            if begin_sls in line and line.strip().endswith(begin_sls):
                foundsls = True
                logger.debug("Start writing log relate to %s", slsname)
                write = True
            if write:
                yield line

    if not foundsls:
        logger.warning("Found no log for SLS: %s", slsname)


def to_skip(line):
    for s in SKIPS:
        if s in line:
            return True
    return False


def output_log_nearby(log_generator, errormsg, count=7):
    beforerr = None
    for line in log_generator:
        if to_skip(line):
            continue
        if errormsg in line:
            print beforerr
            print line
            # print next lines
            for i, line in enumerate(log_generator):
                if to_skip(line):
                    continue
                print line
                if i == count:
                    return
        beforerr = line


@contextmanager
def unxz(xzpath):
    '''
    Make a copy of xzpath, and extract it to be able to choose destination
    dir for extracting.
    Returns path of extracted file.
    '''
    tempdir = tempfile.mkdtemp()
    logger.debug("Copying from %s to %s", xzpath, tempdir)
    shutil.copy(xzpath, tempdir)
    xzcopy = os.path.join(tempdir, os.path.basename(xzpath))
    spr.call(['unxz', xzcopy])
    logtxt = os.path.splitext(xzcopy)[0]

    yield logtxt

    shutil.rmtree(tempdir)
    logger.info("Deleted directory %s and all files under it", tempdir)


def analyze(logtxt, sls, errormsg, outputdir=None):
    ofile = logtxt + ".short.log"

    if outputdir:
        ofile = os.path.join(outputdir, os.path.basename(logtxt))

    with open(ofile, 'w+') as of:
        for line in filtered_logs(logtxt, sls):
            of.write(line)

    with open(ofile) as f:
        output_log_nearby(f, errormsg)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'logfile',
        help='path of log file',
    )
    parser.add_argument('sls',
                        help='name of sls contains error, uses . as path sep')
    parser.add_argument('errorlog',
                        help='error log'
                        )
    parser.add_argument('-C', help='Output dir')

    args = parser.parse_args()

    if args.logfile.startswith('http'):
        args.logfile = link_to_localpath(args.logfile)

    if args.logfile.endswith('.xz'):
        with unxz(args.logfile) as logtxt:
            logger.debug("Extracted, got: %s", logtxt)
            analyze(logtxt, args.sls, args.errorlog, args.C)
    else:
        analyze(args.logfile, args.sls, args.errorlog, args.C)


if __name__ == "__main__":
    main()
#!/bin/bash
# {{ salt['pillar.get']('message_do_not_modify') }}

# Use of this source code is governed by a BSD license that can be
# found in the doc/license.rst file.
#
# Author: Viet Hung Nguyen <hvn@robotinfra.com>
# Maintainer: Viet Hung Nguyen <hvn@robotinfra.com>
#             Bruno Clermont <bruno@robotinfra.com>
# NOTICE: this script executed as jenkins user
# NOTICE: this script use special bash trap to handle error, do not set -e

set -x

PREPARE_STDOUT_LOG=/root/salt/stdout.prepare
PREPARE_STDERR_LOG=/root/salt/stderr.prepare
CUSTOM_CONFIG_DIR=/root/salt/states/test
BUILD_IDENTITY="integration-$JOB_NAME-$BUILD_NUMBER"

function timer {
    finish_run_test_time=$(date +%s)
    echo "TIME-METER: Run integration.py took: $((finish_run_test_time - start_run_test_time)) seconds"
}

function collect_logs {
    timer

    echo "Analysing stdout.log"
    sudo salt -t 30 "$BUILD_IDENTITY" --output json cmd.run "$CUSTOM_CONFIG_DIR/findgap.py --verbose --larger-equal $time_threshold /root/salt/stdout.log"

    for prepare_log in $PREPARE_STDOUT_LOG $PREPARE_STDERR_LOG; do
        sudo salt -t 30 "$BUILD_IDENTITY" --output json cmd.run "xz -c $prepare_log > /tmp/$BUILD_IDENTITY-$(basename $prepare_log).log.xz"
    done

    for ltype in stdout stderr; do
        sudo salt -t 30 "$BUILD_IDENTITY" --output json cmd.run "xz -c /root/salt/$ltype.log > /tmp/$BUILD_IDENTITY-$ltype.log.xz"
    done

    sudo salt -t 30 "$BUILD_IDENTITY" --output json cmd.run "tar -C /var/log -cJf /tmp/$BUILD_IDENTITY-upstart.log.tar.xz upstart"

    sudo salt -t 30 "$BUILD_IDENTITY" --output json cmd.run "grep COUNTER: /root/salt/stdout.log"
    sudo salt -t 60 "$BUILD_IDENTITY" --output json cmd.run_all "salt-call -l info -c $CUSTOM_CONFIG_DIR state.sls test.jenkins.result"

    cp /home/ci-agent/$BUILD_IDENTITY-result.xml $WORKSPACE/result.xml

    xz -d -c /home/ci-agent/$BUILD_IDENTITY-stderr.log.xz
    for f in /home/ci-agent/$BUILD_IDENTITY-*.xz; do
      cp $f $WORKSPACE/`basename $f | sed "s/$BUILD_IDENTITY/$JOB_NAME/"`
    done
    mv /srv/salt/jenkins_archives/$BUILD_IDENTITY.tar.gz $WORKSPACE/bootstrap-archive.tar.gz

    echo "TIME-METER: Total time: $(($(date +%s) - start_time)) seconds"
}

function collect_logs_then_fail {
    collect_logs
    exit 1
}

trap collect_logs_then_fail ERR
trap collect_logs EXIT

start_time=$(date +%s)
rm -f $WORKSPACE/bootstrap-archive.tar.gz $WORKSPACE/stderr.log.xz $WORKSPACE/stdout.log.xz $WORKSPACE/result.xml
rm -rf $WORKSPACE/salt-common-doc
virtualenv --system-site-packages $WORKSPACE/virtualenv
. $WORKSPACE/virtualenv/bin/activate

if [ "${with_ssl:-true}" = "false" ]; then
  $WORKSPACE/common/test/jenkins/generate_non_ssl_pillar.sh pillar
fi

cd common
test/lint.py --warn-nonstable
pip install -r doc/requirements.txt
doc/build.py

if [ "$1" == "--profile" ]; then
    profile=$2
    shift
    shift
else
    profile='ci-minion'
fi
if [ "$1" == "--find-step-longer" ]; then
    time_threshold=${2}
    shift
    shift
else
    time_threshold=30
fi

# allow multiple --repo options to get all non-common repositories
# each value passed to  --repo is relative path to user-specific directory from
# $WORKSPACE. The structure after all SCM checkout looks like:
#  - common
#  - pillar
#  - repo1
#  - repo2
# then use --repo repo1 --repo repo2
# NOTICE --repo must come after --profile if --profile is used.
repos=()
cntr=0
while [ "${1}" = '--repo' ]; do
    repos[${cntr}]="../${2}"
    cntr+=1
    shift
    shift
done

# create archive from common, pillar, and all user-specific formulas repos
./bootstrap_archive.py ../pillar ${repos[@]} > /srv/salt/jenkins_archives/$BUILD_IDENTITY.tar.gz

sudo salt-cloud --profile $profile $BUILD_IDENTITY
sudo salt $BUILD_IDENTITY test.ping | grep True
sudo salt -t 10 "$BUILD_IDENTITY" cmd.run "hostname $BUILD_IDENTITY"
sudo salt -t 60 "$BUILD_IDENTITY" cp.get_file salt://jenkins_archives/$BUILD_IDENTITY.tar.gz /tmp/bootstrap-archive.tar.gz
sudo salt -t 60 "$BUILD_IDENTITY" archive.tar xzf /tmp/bootstrap-archive.tar.gz cwd=/

function run_and_check_return_code {
    sudo salt -t $1 "$BUILD_IDENTITY" --output json cmd.run_all "$2" | ./test/jenkins/retcode_check.py
}

master_ip=$(sudo salt -t 60 "$BUILD_IDENTITY" --out=yaml grains.item master | cut -f2- -d ':' | tr -d '\n')
run_and_check_return_code 10 "sed -i \"s/master:.*/master: $master_ip/g\" $CUSTOM_CONFIG_DIR/minion"
# sync extmod from extracted archive to bootstrapped salt instance
run_and_check_return_code 10 "salt-call -c $CUSTOM_CONFIG_DIR state.sls salt.patch_salt >> $PREPARE_STDOUT_LOG 2>> $PREPARE_STDERR_LOG"
sudo salt -t 20 "$BUILD_IDENTITY" --output json cmd.run "restart salt-minion"
# first cmd after restart often does not return, just ping
sudo salt -t 5 "$BUILD_IDENTITY" --output json cmd.run "salt-call test.ping"
run_and_check_return_code 600 "salt-call -c $CUSTOM_CONFIG_DIR state.sls test.sync >> $PREPARE_STDOUT_LOG 2>> $PREPARE_STDERR_LOG"
run_and_check_return_code 600 "salt-call -c $CUSTOM_CONFIG_DIR state.sls test.jenkins >> $PREPARE_STDOUT_LOG 2>> $PREPARE_STDERR_LOG"
echo '------------ From here, salt with version supported by salt-common is running ------------'
sudo salt -t 5 "$BUILD_IDENTITY" --output json cmd.run "salt-call test.ping"
run_and_check_return_code 20 "salt-call -c $CUSTOM_CONFIG_DIR saltutil.sync_all >> $PREPARE_STDOUT_LOG 2>> $PREPARE_STDERR_LOG"
run_and_check_return_code 10 "salt-call -c $CUSTOM_CONFIG_DIR saltutil.refresh_modules >> $PREPARE_STDOUT_LOG 2>> $PREPARE_STDERR_LOG"

start_run_test_time=$(date +%s)
echo "TIME-METER: Preparing for test took: $((start_run_test_time - start_time)) seconds"
echo '------------ Running CI test  ------------'
sudo salt -t 86400 "$BUILD_IDENTITY" cmd.run "$CUSTOM_CONFIG_DIR/jenkins/run.py $*"

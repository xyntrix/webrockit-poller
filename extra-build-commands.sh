#!/bin/sh

# include any additional steps that need to be followed, just prior to building the rpm here
# this script will be run from the target build target path

PROBLEMS=0
OLDPWD=`pwd`

mkdir -p ./etc/sudoers.d
mv ./opt/phantomjs/collectoids/webrockit-poller/sensu.sudoers ./etc/sudoers.d/sensu
chmod 440 ./etc/sudoers.d/sensu
if [ $? -ne 0 ]
then
    PROBLEMS=99
fi
cd ${OLDPWD}

if [ ${PROBLEMS} -ne 0 ]
then
    exit 1
else
    exit 0
fi

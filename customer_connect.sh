#!/bin/bash

## Creates an SSH tunnel to a single customer site for accessing the launch page.
## Also opens up the launch page in Chrome.
## Requires ecx-sites to be installed.

# Bail on errors
set -e

# Set constants and defaults
SITES_XML="/usr/share/ecx-sites/sites.xml"
ECX="tessex@ecx.dellroad.org"
SSHTUNNEL="ssh -fN -L"

# Print script usage
usage()
{
    echo "    Usage:"
    echo "       `basename $0` [site keyword in lowercase]"
    echo "    Options:"
    echo "       --k   Kill all SSH connections to customers"
    echo "       --h   Display this help"
}

# Find machine in sites.xml
find_machine()
{
    for ARG in ${PARAMETERS[@]}; do
        for MACHINE in ${@}; do
            PATTERN="^([^@]+@)?${MACHINE/./\.}(:.*)?$"
            if [[ "${ARG}" =~ ${PATTERN} ]]; then
                return 0
            elif [[ "${ARG}" = '--k' ]]; then
                echo "Killing SSH connections..."
                kill `ps -ef |grep "ssh -fN" | awk '{print $2}'` 2> /dev/null
                exit 1
            elif [[ "${ARG}" = '--h' ]]; then
                usage
                exit 1
            fi
        done
    done
    return 1
}

# If sites.xml is not where expected, bail
if [ ! -f "${SITES_XML}" ]; then
      echo "Sites config file not found. Please install the ecx-sites package before continuing."
      exit 1
fi

# Copy command line parameters
PARAMETERS=("$@")

# Get the list of machine names
MACHINES=`xml sel -T -t -m //cluster/hosts/host -v "concat('node', count(preceding-sibling::*) + 1)" -o . -v "concat('cluster', count(../../preceding-sibling::*) + 1)" -o . -v ../../../../@keyword -n "${SITES_XML}"`

# Verify a valid machine is specified somewhere on the command line
# If no match, try matching just the site name with "node1.cluster1" prefix
if find_machine ${MACHINES}; then
    FULL_MACHINE="${MACHINE}"
elif find_machine ${MACHINES//node1.cluster1./}; then
    FULL_MACHINE="node1.cluster1.${MACHINE}"
else
    echo "`basename $0`: '$ARG' is not a valid site keyword"
    usage
    exit 1
fi

# Get site info and fonehome port
HOST=`echo ${FULL_MACHINE} | sed -r 's/^node([0-9]+)\.cluster([0-9]+)\.([^.]+)$/\1/g'`
CLUS=`echo ${FULL_MACHINE} | sed -r 's/^node([0-9]+)\.cluster([0-9]+)\.([^.]+)$/\2/g'`
SITE=`echo ${FULL_MACHINE} | sed -r 's/^node([0-9]+)\.cluster([0-9]+)\.([^.]+)$/\3/g'`
PORT=`xml sel -T -t -m "//cluster/hosts/host[count(preceding-sibling::*) + 1 = ${HOST} \
  and count(../../preceding-sibling::*) + 1 = ${CLUS} \
  and ../../../../@keyword = '${SITE}']" -v fonehomePort "${SITES_XML}"`

# Port for accessing launch page
GUIPORT=$[PORT+1]

# Create ssh tunnel to site launch page
echo "Creating connection to $SITE..."
#echo $SSHTUNNEL $GUIPORT:localhost:$GUIPORT
$SSHTUNNEL $GUIPORT:localhost:$GUIPORT $ECX 2> /dev/null || true
#google-chrome http://localhost:$GUIPORT &> /dev/null
firefox http://localhost:$GUIPORT &> /dev/null

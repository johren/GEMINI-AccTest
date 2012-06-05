#!/bin/bash

OMNIPATH=/opt/gcf/src/omni.py
${OMNIPATH} getusercred > /dev/null 2>&1
USERURN=`cat *-usercred.xml | grep owner_urn | sed -e 's/^ *//g;s/ *$//g' | sed -e 's/<owner_urn>//g;s/<\/owner_urn>//g'`
USERNAME=`echo $USERURN | awk -F"+" '{print $4}'`
UNPREFIX=`echo $USERNAME | cut -c1-3`

AM=pg-ky

PREFIX=$1
RSPECPATH=$2
EXPDATE=$3

if [ "${PREFIX}" = "" ]; then
    echo "Must provide prefix to use in slice name"
    exit 1
fi

TIMESTAMP=`date +%y%m%d%H%M`
SLICENAME="${UNPREFIX}${PREFIX}${TIMESTAMP}"
if [ `echo ${SLICENAME} | wc -c` -gt 19 ]; then
    echo "Slice name ${SLICENAME} is too long"
    exit 1
fi

if [ "${RSPECPATH}" = "" ]; then
    echo "Must provide path to rspec template"
    exit 1
fi

if [ ! -r ${RSPECPATH} ]; then
    echo "Could not read ${RSPECPATH}"
    exit 1
fi

# Create the slice using OMNI
echo "Creating slice ${SLICENAME}"
CSLICEOUT=`${OMNIPATH} createslice ${SLICENAME} 2>&1`
echo "${OMNIPATH} createslice ${SLICENAME} 2>&1"
RESULT=`echo ${CSLICEOUT} | grep "Created slice with Name ${SLICENAME}"` 
if [ "${RESULT}" = "" ]; then
    echo "Failed to create slice ${SLICENAME}"
    echo ${CSLICEOUT}
    exit 1
fi

# Create the sliver using OMNI
echo "Creating sliver with rspec ${RSPECPATH}"
CSLIVEROUT=`${OMNIPATH} -a ${AM} -n createsliver ${SLICENAME} ${RSPECPATH} 2>&1`
echo "${OMNIPATH} -a ${AM} -n createsliver ${SLICENAME} ${RSPECPATH} 2>&1"
RESULT=`echo ${CSLIVEROUT} | grep "Completed createsliver:"` 
if [ "${RESULT}" = "" ]; then
    echo "Failed to create sliver for slice ${SLICENAME}"
    echo ${CSLIVEROUT}
    exit 1
fi

# Wait for the sliver to be ready
while true; do
    ${OMNIPATH} -a ${AM} sliverstatus -n ${SLICENAME} > status.out 2>&1 
    if [ -r status.out ]; then
        # Check to see if some of them are ready
        sleep 1
        READYSTATUS=`cat status.out | grep geni_status | grep ready`
        echo "READYSTATUS = ${READYSTATUS}"
        if [ "${READYSTATUS}" != "" ]; then
            # Check to see if they are all ready
            STATUS=`cat status.out | grep geni_status | grep -v ready`
            echo "STATUS = ${STATUS}"
            if [ "${STATUS}" = "" ]; then
                break
            fi
        fi
    fi
    echo "Waiting for slice to be ready..."
    sleep 3 
done

if [ "${EXPDATE}" != "" ]; then
    # Renew the slice
    echo "Renewing slice ${SLICENAME} to ${EXPDATE}"
    RSLICEOUT=`${OMNIPATH} -a ${AM} -n renewslice ${SLICENAME} ${EXPDATE} 2>&1`
    echo $RSLICEOUT > renewout
    # Renew the sliver
    echo "Renewing sliver ${SLICENAME} to ${EXPDATE}"
    RSLIVEROUT=`${OMNIPATH} -a ${AM} -n renewsliver ${SLICENAME} ${EXPDATE} 2>&1`
    echo $RSLIVEROUT >> renewout
fi

# Get the manifest
${OMNIPATH} -a ${AM} listresources -o ${SLICENAME}

/opt/gcf/examples/readyToLogin.py ${SLICENAME}


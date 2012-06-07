#!/bin/bash

OMNIPATH=/opt/gcf/src/omni.py
${OMNIPATH} getusercred > /dev/null 2>&1
USERURN=`cat *-usercred.xml | grep owner_urn | sed -e 's/^ *//g;s/ *$//g' | sed -e 's/<owner_urn>//g;s/<\/owner_urn>//g'`
USERNAME=`echo $USERURN | awk -F"+" '{print $4}'`
UNPREFIX=`echo $USERNAME | cut -c1-3`

PREFIX=""
RSPECPATH=""
EXPDATE=""
SLICENAME=""
AGGREGATE="pg-ky"

# options may be followed by one colon to indicate they have a required argument
# p = prefix (required if no slicename provided)
# r = rspec (required)
# e = expiration date
# a = aggregate
# n = slicename (required if no prefix provided)
if ! options=$(getopt -o p:r:e:a:n: -l prefix:,rspec:,exp:,agg:,slice: -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi

set -- $options

while [ $# -gt 0 ]
do
    case $1 in
    -p|--prefix) PREFIX=`echo $2 | sed -e "s/'//g"` ; shift;;
    -r|--rspec) RSPECPATH=`echo $2 | sed -e "s/'//g"`; shift;;
    -e|--exp) EXPDATE=`echo $2 | sed -e "s/'//g"` ; shift;;
    -a|--agg) AGGREGATE=`echo $2 | sed -e "s/'//g"` ; shift;;
    -n|--slice) SLICENAME=`echo $2 | sed -e "s/'//g"` ; shift;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
    esac
    shift
done

if [ "${SLICENAME}" == "" ]; then
    if [ "${PREFIX}" = "" ]; then
        echo "Must provide prefix to use in slice name"
        exit 1
    fi
    TIMESTAMP=`date +%y%m%d%H%M`
    SLICENAME="${UNPREFIX}${PREFIX}${TIMESTAMP}"
fi

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
CSLIVEROUT=`${OMNIPATH} -a ${AGGREGATE} -n createsliver ${SLICENAME} ${RSPECPATH} 2>&1`
echo "${OMNIPATH} -a ${AGGREGATE} -n createsliver ${SLICENAME} ${RSPECPATH} 2>&1"
RESULT=`echo ${CSLIVEROUT} | grep "Completed createsliver:"` 
if [ "${RESULT}" = "" ]; then
    echo "Failed to create sliver for slice ${SLICENAME}"
    echo ${CSLIVEROUT}
    exit 1
fi

# Wait for the sliver to be ready
while true; do
    ${OMNIPATH} -a ${AGGREGATE} sliverstatus -n ${SLICENAME} > status.out 2>&1 
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
    RSLICEOUT=`${OMNIPATH} -a ${AGGREGATE} -n renewslice ${SLICENAME} ${EXPDATE} 2>&1`
    echo $RSLICEOUT > renewout
    # Renew the sliver
    echo "Renewing sliver ${SLICENAME} to ${EXPDATE}"
    RSLIVEROUT=`${OMNIPATH} -a ${AGGREGATE} -n renewsliver ${SLICENAME} ${EXPDATE} 2>&1`
    echo $RSLIVEROUT >> renewout
fi

# Get the manifest
${OMNIPATH} -a ${AGGREGATE} listresources -o ${SLICENAME}

/opt/gcf/examples/readyToLogin.py ${SLICENAME}


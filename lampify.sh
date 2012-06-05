#!/bin/bash

OMNIPATH=/opt/gcf/src/omni.py

${OMNIPATH} getusercred > /dev/null 2>&1
USERURN=`cat *-usercred.xml | grep owner_urn | sed -e 's/^ *//g;s/ *$//g' | sed -e 's/<owner_urn>//g;s/<\/owner_urn>//g'`
USERNAME=`echo $USERURN | awk -F"+" '{print $4}'`

AM=pg-ky
CM="https://www.emulab.net/protogeni/xmlrpc/cm"

SLICENAME=$1
MANIFESTPATH=$2

if [ "${SLICENAME}" = "" ]; then
    echo "Must provide slice name"
    exit 1
fi
if [ `echo ${SLICENAME} | wc -c` -gt 19 ]; then
    echo "Slice name ${SLICENAME} is too long"
    exit 1
fi

if [ "${MANIFESTPATH}" = "" ]; then
    echo "Must provide path to manifest file"
    exit 1
fi

if [ ! -r ${MANIFESTPATH} ]; then
    echo "Cannot read ${MANIFESTPATH}"
    exit 1
fi


# Get the slice credential using protogeni test script (remove first line from the file)
CREDFILE="${SLICENAME}-cred.xml"
/opt/protogeni/getslicecredential.py -n ${SLICENAME} > ${CREDFILE}.temp 
echo "/opt/protogeni/getslicecredential.py -n ${SLICENAME} > ${CREDFILE}.temp"
# Remove the first line from the file
 sed -e "1d" ${CREDFILE}.temp > ${CREDFILE}
# rm -f ${CREDFILE}.temp
if [ ! -s ${CREDFILE} ]; then
    echo "Failed to get slice credential for slice ${SLICENAME}"
    exit 1
fi 

# Get the urn for the slice
SLICEURN=`cat ${CREDFILE} | grep target_urn | sed -e 's/^ *//g;s/ *$//g' | sed -e 's/<target_urn>//g;s/<\/target_urn>//g'`

# Send the manifest to UNIS
/opt/protogeni/lamp-sendmanifest.py ${MANIFESTPATH} ${SLICEURN} ${CREDFILE} > sendmanifest.result
echo "/opt/protogeni/lamp-sendmanifest.py ${MANIFESTPATH} ${SLICEURN} ${CREDFILE} > sendmanifest.result"
SUCCESS=`cat sendmanifest.result | grep "data element(s) successfully replaced"`
#rm -f sendmanifest.result
if [ "${SUCCESS}" = "" ]; then
    echo "Failed to send manifest to UNIS"
    exit 1
fi

# Get the LAMP certificate from the LAMP CA
/opt/protogeni/lamp-getcertificate.py -n ${SLICENAME} > lampcert.pem.temp
echo "/opt/protogeni/lamp-getcertificate.py -n ${SLICENAME} > lampcert.pem.temp"
# Remove the first six lines of the file
sed -e "1,6d" lampcert.pem.temp > lampcert.pem
#rm -f lampcert.pem.temp
KEYISTHERE=`cat lampcert.pem | grep "BEGIN RSA PRIVATE KEY"`
CERTISTHERE=`cat lampcert.pem | grep "BEGIN CERTIFICATE"`
if [ "${KEYISTHERE}" = "" -o "${CERTISTHERE}" = "" ]; then
    echo "Failed to get valid certificate from LAMP CA"
    exit 1
fi 

# Install the LAMP certificate on all of the nodes in the slice
RESULT=`/opt/protogeni/placelampcert.sh ${MANIFESTPATH} lampcert.pem | grep "No certificate"`
echo "/opt/protogeni/placelampcert.sh ${MANIFESTPATH} lampcert.pem | grep No certificate"
if [ "${RESULT}" != "" ]; then
    echo "Failed to place certificate on some nodes"
    echo "${RESULT}"
    exit 1
fi



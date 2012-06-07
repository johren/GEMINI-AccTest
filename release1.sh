#! /bin/bash
MANIFESTFILE=$1
CREDFILE=$2
if [ "${MANIFESTFILE}" = "" ]; then
    echo "Must provide path to manifest file"
    exit 1
fi
if [ ! -r ${MANIFESTFILE} ]; then
    echo "Could not read ${MANIFESTFILE}"
    exit 1
fi
if [ "${CREDFILE}" = "" ]; then
    echo "Must provide path to slice credential file"
    exit 1
fi
if [ ! -r ${CREDFILE} ]; then
    echo "Could not read ${CREDFILE}"
    exit 1
fi

# Get the urn for the user
USERURN=`cat *-usercred.xml | grep owner_urn | sed -e 's/^ *//g;s/ *$//g' | sed -e 's/<owner_urn>//g;s/<\/owner_urn>//g'`
if [ "${USERURN}" = "" ]; then
    echo "Could not determine USERURN"
    exit 1
fi
USERNAME=`echo $USERURN | awk -F"+" '{print $4}'`
if [ "${USERNAME}" = "" ]; then
    echo "Could not determine USERNAME"
    exit 1
fi


# Get the urn for the slice
SLICEURN=`cat ${CREDFILE} | grep target_urn | sed -e 's/^ *//g;s/ *$//g' | sed -e 's/<target_urn>//g;s/<\/target_urn>//g'`
if [ "${SLICEURN}" = "" ]; then
    echo "Could not determine SLICEURN"
    exit 1
fi


NODES=`grep login $MANIFESTFILE | sed -e 's/^ *//g;s/ *$//g' | awk '{print $9, $10}' | sed -e 's/hostname=//g' | sed -e 's/port=//g' | sed -e 's/"//g' | sed -e 's/ /:/g'`

for node in $NODES; do
    HOST=`echo $node | cut -d":" -f1` 
    PORT=`echo $node | cut -d":" -f2`
    if [ "${PORT}" == "22" ]; then
        echo "Installing GN software on node ${HOST} port ${PORT}" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo wget https://github.com/downloads/GENI-GEMINI/GEMINI/gemini-gn-active-ubuntu10-20120531.tar.gz"
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo tar -zxvf gemini-gn-active-ubuntu10-20120531.tar.gz"
        echo "   Installing Shared-Ubuntu.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./Shared-Ubuntu.sh"
        echo "   Installing LAMP certificate" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo install -o root -g perfsonar -m 440 lampcert.pem /usr/local/etc/protogeni/ssl/"
        echo "   Running bootstrap" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo /usr/local/etc/lamp/bootstrap.sh ${SLICEURN} ${USERURN}"
        echo "   Installing apache2-Ubuntu.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./apache2-Ubuntu.sh"
        echo "   Installing perfSONAR_PS-ServiceWatcher-Ubuntu.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-ServiceWatcher-Ubuntu.sh"
        echo "   Installing perfSONAR_PS-Toolkit-Ubuntu.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-Toolkit-Ubuntu.sh"
      
    else
        echo "Installing MP software on node ${HOST} port ${PORT}" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo wget https://github.com/downloads/GENI-GEMINI/GEMINI/gemini-mp-active-fedora15-20120531.tar.gz"
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo tar -zxvf gemini-mp-active-fedora15-20120531.tar.gz"
        echo "   Installing Shared-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./Shared-Fedora.sh"
        echo "   Installing LAMP certificate" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo install -o root -g perfsonar -m 440 lampcert.pem /usr/local/etc/protogeni/ssl/"
        echo "   Running bootstrap" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo /usr/local/etc/lamp/bootstrap.sh ${SLICEURN} ${USERURN}"
        echo "   Installing mysql-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./mysql-Fedora.sh"
        echo "   Installing perfSONAR_PS-ServiceWatcher-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-ServiceWatcher-Fedora.sh"
        echo "   Installing perfSONAR_PS-psConfig-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-pSConfig-Fedora.sh"
        echo "   Installing perfSONAR_PS-LSRegistrationDaemon-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-LSRegistrationDaemon-Fedora.sh"
        echo "   Installing perfSONAR_PS-perfSONARBUOY-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-perfSONARBUOY-Fedora.sh"
        echo "   Installing perfSONAR_PS-PingER-Fedora.sh" 
        ssh -p ${PORT} ${USERNAME}@${HOST} "sudo ./perfSONAR_PS-PingER-Fedora.sh"
    fi
done

for node in $NODES; do
    HOST=`echo $node | cut -d":" -f1` 
    PORT=`echo $node | cut -d":" -f2`
    #ssh -p $PORT ${USERNAME}@${HOST} "sudo ls /usr/local/etc/protogeni/ssl/lampcert.pem"
done


#!/bin/bash
#printf "\E[0;31mPlease make sure you have commited the bundles for the target branch.\E[0m\n\n"
if [ -z ${VMSS_ENV} ]; then
   echo "[ERROR] VMSS_ENV is not set. Please setup the env variable 'VMSS_ENV' first."
   exit 0
fi
printf "Please enter release version: [9.4.1]\n"
read RELEASE_VERSION
printf "Please enter release type: [beta|pro]\n"
read RELEASE_TYPE


# to uppercase/lowercase
RELEASE_TYPE_UPPERCASE="${RELEASE_TYPE^^}"
RELEASE_TYPE_LOWERCASE="${RELEASE_TYPE,,}"
BRANCH="LN-$RELEASE_VERSION"
FOLDER="LN_$RELEASE_TYPE_UPPERCASE-$RELEASE_VERSION"

printf "\n########## Start deployment: $FOLDER ##########\n\n"

########## Start deployment: $FOLDER ##########

# clone git repository
cd /ad-hub.net/apps/release/
if [ -d "$FOLDER" ]; then
    rm -rf $FOLDER
fi
git -c http.sslVerify=false clone http://wagaru:37784de0c079dc44bbbd900c6901f7cca877022a@gogs.funptw/adHub/line.git -b $BRANCH $FOLDER

if [ $? -ne 0 ]
then
    printf "===== [ERROR] Clone git repository failed! =====\n"
    exit
fi


# run make script
cd /ad-hub.net/apps/release/$FOLDER
make $RELEASE_TYPE_LOWERCASE

if [ $? -ne 0 ]
then
    printf "===== [ERROR] Run Makefile failed! =====\n"
    exit
fi


# link to correct folder
cd /ad-hub.net/apps/
rm -rf line_$RELEASE_TYPE_LOWERCASE && ln -s /ad-hub.net/apps/release/$FOLDER line_$RELEASE_TYPE_LOWERCASE

if [ $? -ne 0 ]
then
    printf "===== [ERROR] Update soft link failed! =====\n"
    exit
fi

# restart memcache & php-fpm & nginx
#if [ "$RELEASE_TYPE_UPPERCASE" = "PRO" ]
#then
#	   service memcached restart session && service nginx stop && service php-fpm stop && service php-fpm start && service nginx start;
#fi

#if [ $? -eq 0 ]
#then
    printf "\n########## Finish deployment: $FOLDER ##########\n\n"
#else
#    printf "===== Restart memcached & php-fpm & nginx failed! =====\n"
#fi
exit

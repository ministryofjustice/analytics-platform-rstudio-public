#!/bin/bash
set -e

GROUP=staff
USER_UID=1001

if [ "$(id -u "$USER" 2>/dev/null)" != $USER_UID ]; then
    useradd -g $GROUP -u $USER_UID -d /home/$USER $USER
fi

# this is only for running locally - in-cluster, home directories are
# provided via NAS
echo "${USER}:${USER}" | chpasswd
if [ ! -d /home/$USER ]; then
    mkdir -p /home/$USER
fi
chown "${USER}:${GROUP}" /home/$USER

# set secure cookie key
 echo -n "${SECURE_COOKIE_KEY}" > /var/lib/rstudio-server/secure-cookie-key
chmod 600 /var/lib/rstudio-server/secure-cookie-key

/usr/lib/rstudio-server/bin/rserver --server-daemonize=0

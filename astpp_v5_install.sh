#!/bin/bash
#############################################################################################
# ASTP v1.0.0-beta1  installer for ASTPP version 5
#
#
# This installation script is partly based on the iNetrix Technologies Pvt. Ltd.
# installtion script for installing ASTPP.
#
# This script will only install version 5 of ASTPP, and for using only
# Debian 10 and 11.
#
# The purpose of this script is for multiple reasons compared to the one
# providedby iNetrix:
#
# 1) Compiles FreeSwitch from source instead of using the SignalWire repo
#    which requires a SignalWire account with a token attached to that account
#
# 2) Uses MariaDB from the Debian repo instead of MySQL from their repo.
#    This has caused issues in the past
#
# 3) Does not use RemiRepo for PHP 7.3+. iNetrix for unknown reasons uses the RemiRepo
#
# 4) No longer support of CentOS 7/8 as those are End of Life
#    CentOS Stream is now the default distro, and not stable for production
#    May consider Rocky Linux 8 (CentOS 8 fork) in the future
#
# 5) Option to install Postfix instead of sendmail which provides better logging
#
# 6) No telemetry sent
#
# License https://www.gnu.org/licenses/agpl-3.0.html
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#############################################################################################



# Sofia-Sip Version
sofia_version=1.13.7                        # release-version for sofia-sip to use

# FreeSWITCH Version
switch_version=1.10.7                       # which source code to download, only for source


#General Congifuration
TEMP_USER_ANSWER="no"
ASTPP_SOURCE_DIR=/opt/ASTPP
ASTPP_HOST_DOMAIN_NAME="host.domain.tld"
os_codename=$(lsb_release -cs)


#ASTPP Configuration
ASTPPDIR=/var/lib/astpp/
ASTPPEXECDIR=/usr/local/astpp/
ASTPPLOGDIR=/var/log/astpp/


#HTML and MariaDB Configuraition
WWWDIR=/var/www/html
ASTPP_DATABASE_NAME="astpp"
ASTPP_DB_USER="astppuser"

#Freeswich Configuration
FS_DIR=/usr/share/freeswitch
FS_SOUNDSDIR=${FS_DIR}/sounds/en/us/callie




#Introduction
introduction()
{

printf "\033c"
echo ""
echo "**************** INTRODUCTION *******************"
echo ""
echo "This is an alternative to the iNetrix ASTPP installer."
echo "Their installer uses third party package repositories (repos) which has been having a lot of issues "
echo "in the past due to the use of those third party repos."
echo ""
echo "This installer instead will use only the Debian repo to install most of the needed requirements"
echo ""
echo "Do note, since this will compile* FreeSwitch from source, there will be a lot of packages which will"
echo "need to be locally installed. This process of installing packages and compiling of FreeSwitch"
echo "will take much longer than the iNetrix installer, but without the need for third party packages,"
echo "nor having to obtain an account with SignalWire."
echo ""
echo "Enjoy!"
echo ""
echo ""
echo ""
echo "*Compile time of FreeSwitch varies depending on performance of your server, and number of CPUs. "
echo ""
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"




}




pre_install()
{

printf "\033c"

echo ""
echo "********************************"
echo "!!!!!!!!!!!!! NOTICE !!!!!!!!!!!"
echo "********************************"
echo ""
echo "This part of the script will give the option to install Postfix instead of Sendmail. "
echo "Postifx is preferred as it produces better logs than Sendmail in case for the need to troubleshoot sending email issues. "
echo "During installation of postfix, it will require some manual configurations, but the defaults will be ready to select."
echo ""
echo "You will only need to press the enter key to continue for the two questions, HOWEVER, it is reccomended you have the server" 
echo "Fully Qualified Domain Name (FQDN)/hosname already set (e.g. astpp.myserver.com) before continuing beyond this point."
echo ""
echo "If you have not done so, the FQDN/hostname can be easily set, as an example, with the command: "
echo "hostnamectl set-hostname astpp.yourhostname.com"
echo ""
echo "You will have to reboot/relog to make sure changes have been made."
echo ""
echo "As an alternative, you can select 'n' to instead install Sendmail. No additonal configuration is needed for it."
echo ""



read -n 1 -p "Do you wish to continue with installation of Postfix? (y/n/q[uit]) "
                if [ "$REPLY"   = "y" ]; then

			echo ""
			echo "Now installing Postfix"
			echo ""
			apt -y install postfix
		elif [ "$REPLY"   = "n" ]; then
			echo ""
			echo "Now installing Sendmail"
			echo ""
			apt -y install sendmail
		elif [ "$REPLY"   = "q" ]; then
			echo ""
			echo "Exiting"
			echo ""
			exit 0

		fi

} #end of pre_install










#Generate random password
genpasswd()
{
        length=$1
        digits=({1..9})
        lower=({a..z})
        upper=({A..Z})
        CharArray=(${digits[*]} ${lower[*]} ${upper[*]})
        ArrayLength=${#CharArray[*]}
        password=""
        for i in `seq 1 $length`
        do
                index=$(($RANDOM%$ArrayLength))
                char=${CharArray[$index]}
                password=${password}${char}
        done
        echo $password
}




get_linux_distribution()
{


        if [ $os_codename != 'buster' ] && [ $os_codename != 'bullseye' ]; then

                echo -e 'Sorry, but this script is only for Debian 10, and Debian 11.'
				exit 1

        fi

} # endget_linux_distribution

#User Response Gathering
get_user_response ()
{

        echo ""
        echo ""
        read -p "Enter aFQDN example (i.e ${ASTPP_HOST_DOMAIN_NAME}), or an IP Address for this server: "
        ASTPP_HOST_DOMAIN_NAME=${REPLY}
        echo "Your entered FQDN is : ${ASTPP_HOST_DOMAIN_NAME} "
        echo ""
        echo ""
        read -n 1 -p "Press any key to continue ... "
        NAT1=$(dig +short myip.opendns.com @resolver1.opendns.com)
        NAT2=$(curl http://ip-api.com/json/)
        INTF=$(ifconfig $1|sed -n 2p|awk '{ print $2 }'|awk -F : '{ print $2 }')
        if [ "${NAT1}" != "${INTF}" ]; then
                echo "Server is behind NAT";
                NAT="True"
        fi

}

install_prerequisties()
{

# install dependencies


apt update && apt -y upgrade

apt -y install wget lsb-release  systemd-sysv ca-certificates dialog nano net-tools openssl libssl-dev \
autoconf automake devscripts g++ git libncurses5-dev libtool make libjpeg-dev pkg-config flac libgdbm-dev \
libdb-dev gettext sudo equivs mlocate git dpkg-dev libpq-dev liblua5.2-dev libtiff5-dev libperl-dev \
libcurl4-openssl-dev libsqlite3-dev libpcre3-dev devscripts libspeexdsp-dev libspeex-dev libldns-dev \
libedit-dev libopus-dev libmemcached-dev libshout3-dev libmpg123-dev libmp3lame-dev yasm nasm libsndfile1-dev \
libuv1-dev libvpx-dev libavformat-dev libswscale-dev libvlc-dev libavformat-dev libswscale-dev libsndfile-dev \
wget curl git dnsutils ntpdate systemd net-tools whois sensible-mda mlocate vim imagemagick \
php-pear php-imagick libreoffice ghostscript sngrep software-properties-common lsb-release \
apt-transport-https ca-certificates unixodbc unixodbc-bin cmake uuid-dev sqlite3 unzip mariadb-server \
nginx ntpdate ntp lua5.1 bc libxml2-dev ed

#Ion Cube Loader

cd /usr/src/
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar -xzvf ioncube_loaders_lin_x86-64.tar.gz

sed -i "s|PermitRootLogin without-password\+|PermitRootLogin yes|g" /etc/ssh/sshd_config
systemctl restart sshd

} #end install_prerequisties

#install dependencies that depend on the operating system version


os_dependencies()
{

os_codename=$(lsb_release -cs)


if [ ."$os_codename" = ."buster" ]; then

#Need to add backports for IP tables 1.8.3 and monit.
        printf "%s\n" "deb http://ftp.de.debian.org/debian buster-backports main" | \
        tee /etc/apt/sources.list.d/buster-backports.list

	apt update

        apt install -t buster-backports iptables -y 

	apt install -y libvpx5 swig3.0 python3-distutils 
	apt install -y php7.3 php7.3-fpm php7.3-mysql php7.3-cli php7.3-json php7.3-readline php7.3-xml php7.3-curl
	apt install -y php7.3-gd php7.3-json php7.3-mbstring php7.3-mysql php7.3-opcache php7.3-imap
fi
if [ ."$os_codename" = ."bullseye" ]; then

        #Need to add backports for IP tables 1.8.3 and monit.
	printf "%s\n" "deb http://ftp.de.debian.org/debian buster-backports main" | \
	tee /etc/apt/sources.list.d/buster-backports.list

	apt install -t buster-backports iptables -y 
	apt install -y libvpx6 swig4.0 python3-distutils
	apt install -y php7.4 php7.4-fpm php7.4-mysql php7.4-cli php7.4-json php7.4-readline php7.4-xml php7.4-curl
	apt install -y php7.4-gd php7.4-json php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-imap
fi

} #end os_dependencies


freeswitch_source_dependencies()
{

###FreeSwitch Source dependencies

# libks
	cd /usr/src
	git clone https://github.com/signalwire/libks.git libks
	cd libks
	cmake .
	make -j$(($(getconf _NPROCESSORS_ONLN)+1))
	make install
        ldconfig
	# libks C includes
	export C_INCLUDE_PATH=/usr/include/libks


# spandsp
	cd /usr/src
	git clone https://github.com/freeswitch/spandsp.git spandsp
	cd spandsp
	sh autogen.sh
	./configure
	make -j$(($(getconf _NPROCESSORS_ONLN)+1))
	make install
	ldconfig

# sofia-sip
	cd /usr/src
	wget https://github.com/freeswitch/sofia-sip/archive/refs/tags/v1.13.7.tar.gz
	tar xf v1.13.7.tar.gz
	cd sofia-sip-1.13.7
	sh autogen.sh
	./configure
	make -j$(($(getconf _NPROCESSORS_ONLN)+1))
	make install
	ldconfig

} # end freeswitch_source_dependencies


##########################################
###########Compile and install FreeSwitch
##########################################


install_freeswitch()
{


cd /usr/src
wget https://files.freeswitch.org/freeswitch-releases/freeswitch-$switch_version.-release.tar.gz
tar xf freeswitch-$switch_version.-release.tar.gz
cd freeswitch-$switch_version.-release


sed -i "s/applications\/mod_signalwire/#applications\/mod_signalwire/g" modules.conf
sed -i "s/formats\/mod_sndfile/#formats\/mod_sndfile/g" modules.conf


# enable required modules
sed -i modules.conf -e s:'#applications/mod_av:formats/mod_av:'
sed -i modules.conf -e s:'#applications/mod_callcenter:applications/mod_callcenter:'
sed -i modules.conf -e s:'#applications/mod_cidlookup:applications/mod_cidlookup:'
sed -i modules.conf -e s:'#applications/mod_memcache:applications/mod_memcache:'
sed -i modules.conf -e s:'#applications/mod_nibblebill:applications/mod_nibblebill:'
sed -i modules.conf -e s:'#applications/mod_curl:applications/mod_curl:'
sed -i modules.conf -e s:'#formats/mod_shout:formats/mod_shout:'
sed -i modules.conf -e s:'#say/mod_say_es:say/mod_say_es:'
sed -i modules.conf -e s:'#say/mod_say_fr:say/mod_say_fr:'


#disable module or install dependency libks to compile signalwire
sed -i modules.conf -e s:'applications/mod_signalwire:#applications/mod_signalwire:'
sed -i modules.conf -e s:'endpoints/mod_skinny:#endpoints/mod_skinny:'
sed -i modules.conf -e s:'endpoints/mod_verto:#endpoints/mod_verto:'


# prepare the build
./configure --prefix=/usr/local/freeswitch --with-openssl

# compile and install
make -j$(($(getconf _NPROCESSORS_ONLN)+1))
make install
make sounds-install moh-install
make hd-sounds-install hd-moh-install
make cd-sounds-install cd-moh-install

#sed -i "s/#formats\/mod_sndfile/formats\/mod_sndfile/g" /usr/src/freeswitch-$switch_version.-release/modules.conf
sed -i "s/#formats\/mod_sndfile/formats\/mod_sndfile/g" modules.conf
make mod_sndfile-install

#move the music into music/default directory
#mkdir -p /usr/share/freeswitch/sounds/music/default
#mv /usr/share/freeswitch/sounds/music/*000 /usr/share/freeswitch/sounds/music/default



ln -s /usr/local/freeswitch/conf /etc/freeswitch
ln -s /usr/local/freeswitch/bin/fs_cli /usr/bin/fs_cli
ln -s /usr/local/freeswitch/bin/freeswitch /usr/sbin/freeswitch



mv -f ${FS_DIR}/scripts /tmp/.
ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
ln -s ${ASTPP_SOURCE_DIR}/freeswitch/scripts ${FS_DIR}
cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/sounds/*.wav ${FS_SOUNDSDIR}/
cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/conf/autoload_configs/* /usr/local/freeswitch/etc/freeswitch/autoload_configs/










#Creating freeswitch user
groupadd freeswitch
adduser --quiet --system --home /usr/local/freeswitch --gecos 'FreeSWITCH' --ingroup freeswitch freeswitch --disabled-password 
chown -R freeswitch:freeswitch /usr/local/freeswitch/
chmod -R ug=rwX,o= /usr/local/freeswitch/
chmod -R u=rwx,g=rx /usr/local/freeswitch/bin/*

#Add FreeSwitch as Systemd background service
/bin/cat <<'EOTT' >/etc/systemd/system/freeswitch.service

[Unit]
Description=FreeSWITCH open source softswitch
Wants=network-online.target Requires=network.target local-fs.target
After=network.target network-online.target local-fs.target

[Service]
; service
Type=forking
PIDFile=/usr/local/freeswitch/var/run/freeswitch/freeswitch.pid
Environment="DAEMON_OPTS=-nonat"
Environment="USER=freeswitch"
Environment="GROUP=freeswitch"
EnvironmentFile=-/etc/default/freeswitch
ExecStartPre=/bin/chown -R ${USER}:${GROUP} /usr/local/freeswitch
ExecStart=/usr/local/freeswitch/bin/freeswitch -u ${USER} -g ${GROUP} -ncwait ${DAEMON_OPTS}
TimeoutSec=45s
Restart=always

[Install]
WantedBy=multi-user.target
EOTT

} #end install_freeswitch



normalize_freeswitch()
{
        systemctl start freeswitch
        systemctl enable freeswitch
        sed -i "s#max-sessions\" value=\"1000#max-sessions\" value=\"2000#g" /usr/local/freeswitch/etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#sessions-per-second\" value=\"30#sessions-per-second\" value=\"50#g" /usr/local/freeswitch/etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#max-db-handles\" value=\"50#max-db-handles\" value=\"500#g" /usr/local/freeswitch/etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#db-handle-timeout\" value=\"10#db-handle-timeout\" value=\"30#g" /usr/local/freeswitch/etc/freeswitch/autoload_configs/switch.conf.xml
        rm -rf  /etc/freeswitch/dialplan/*
        touch /usr/local/freeswitch/etc/freeswitch/dialplan/astpp.xml
        rm -rf  /usr/local/freeswitch/etc/freeswitch/directory/*
        touch /usr/local/freeswitch/etc/freeswitch/directory/astpp.xml
        rm -rf  /usr/local/freeswitch/etc/freeswitch/sip_profiles/*
        touch /usr/local/freeswitch/etc/freeswitch/sip_profiles/astpp.xml
        chmod -Rf 755 ${FS_SOUNDSDIR}
        chmod -Rf 777 /usr/share/freeswitch/scripts/astpp/lib

        cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_fs.conf /etc/nginx/conf.d/fs.conf
        chown -Rf root.root ${WWWDIR}/fs
        chmod -Rf 755 ${WWWDIR}/fs
        /bin/systemctl restart freeswitch
        /bin/systemctl enable freeswitch

} #end normalize_freeswitch


normalize_mariadb()
{
cp ${ASTPP_SOURCE_DIR}/misc/odbc/deb_odbc.ini /etc/odbc.ini
sed -i '1i wait_timeout=600' /etc/mysql/conf.d/mysql.cnf
sed -i '1i interactive_timeout = 600' /etc/mysql/conf.d/mysql.cnf
sed -i '1i sql_mode=""' /etc/mysql/conf.d/mysql.cnf
sed -i '1i [mysqld]' /etc/mysql/conf.d/mysql.cnf

systemctl restart mariadb
systemctl enable mariadb

} #end normalize_mariadb

#Fetch ASTPP Source
get_astpp_source()
{
        cd /opt
        git clone -b v5.0 https://github.com/iNextrix/ASTPP.git
} #end get_astpp_source


install_fail2ban()
{
                read -n 1 -p "Do you want to install and configure Fail2ban ? (y/n) "
                if [ "$REPLY"   = "y" ]; then

                            sleep 2s
                            apt update -y
                            sleep 2s
                            apt install fail2ban -y
                            sleep 2s
                            echo ""
                            read -p "Enter fail2ban client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /usr/src
                            #wget --no-check-certificate --max-redirect=0 https://latest.astppbilling.org/fail2ban_Deb.tar.gz
                            #tar xzvf fail2ban_Deb.tar.gz
                            mv /etc/fail2ban /tmp/
                            cd ${ASTPP_SOURCE_DIR}/misc/
                            tar -xzvf fail2ban_deb10.tar.gz
                            cp -rf ${ASTPP_SOURCE_DIR}/misc/fail2ban_deb10 /etc/fail2ban
                            #cp -rf /usr/src/fail2ban /etc/fail2ban
                            #cp -rf ${ASTPP_SOURCE_DIR}/misc/deb_files/fail2ban/jail.local /etc/fail2ban/jail.local

                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local

                        ################################# JAIL.CONF FILE READY ######################
                        echo "################################################################"
                        mkdir /var/run/fail2ban
                        systemctl restart fail2ban
                        systemctl enable fail2ban
                        echo "################################################################"
                        echo "Fail2Ban for FreeSwitch & IPtables Integration completed"
                        else
                        echo ""
                        echo "Fail2ban installation is aborted !"
                fi
} #end install_fail2ban



install_astpp()
{
echo "Creating neccessary locations and configuration files ..."
mkdir -p ${ASTPPDIR}
mkdir -p ${ASTPPLOGDIR}
mkdir -p ${ASTPPEXECDIR}
mkdir -p ${WWWDIR}
cp -rf ${ASTPP_SOURCE_DIR}/config/astpp-config.conf ${ASTPPDIR}astpp-config.conf
cp -rf ${ASTPP_SOURCE_DIR}/config/astpp.lua ${ASTPPDIR}astpp.lua
ln -s ${ASTPP_SOURCE_DIR}/web_interface/astpp ${WWWDIR}
ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}

} #end install_astpp


normalize_astpp()
{
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt



if [ ."$os_codename" = ."buster" ]; then

/bin/cp /usr/src/ioncube/ioncube_loader_lin_7.3.so /usr/lib/php/20180731/
sed -i '2i zend_extension ="/usr/lib/php/20180731/ioncube_loader_lin_7.3.so"' /etc/php/7.3/fpm/php.ini
sed -i '2i zend_extension ="/usr/lib/php/20180731/ioncube_loader_lin_7.3.so"' /etc/php/7.3/cli/php.ini
cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_astpp.conf /etc/nginx/conf.d/astpp.conf
systemctl start nginx
systemctl enable nginx
systemctl start php7.3-fpm
systemctl enable php7.3-fpm
chown -Rf root.root ${ASTPPDIR}
chown -Rf www-data.www-data ${ASTPPLOGDIR}
chown -Rf root.root ${ASTPPEXECDIR}
chown -Rf www-data.www-data ${WWWDIR}/astpp
chown -Rf www-data.www-data ${ASTPP_SOURCE_DIR}/web_interface/astpp
chmod -Rf 755 ${WWWDIR}/astpp
sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php/7.3/fpm/php.ini
sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php/7.3/fpm/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php/7.3/fpm/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php/7.3/fpm/php.ini
sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php/7.3/fpm/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.3/fpm/php.ini
systemctl restart php7.3-fpm

fi

if [ ."$os_codename" = ."bullseye" ]; then
/bin/cp /usr/src/ioncube/ioncube_loader_lin_7.4.so /usr/lib/php/20190902/
sed -i '2i zend_extension ="/usr/lib/php/20190902/ioncube_loader_lin_7.4.so"' /etc/php/7.4/fpm/php.ini
sed -i '2i zend_extension ="/usr/lib/php/20190902/ioncube_loader_lin_7.4.so"' /etc/php/7.4/cli/php.ini
cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_astpp.conf /etc/nginx/conf.d/astpp.conf
systemctl start nginx
systemctl enable nginx
systemctl start php7.4-fpm
systemctl enable php7.4-fpm
chown -Rf root.root ${ASTPPDIR}
chown -Rf www-data.www-data ${ASTPPLOGDIR}
chown -Rf root.root ${ASTPPEXECDIR}
chown -Rf www-data.www-data ${WWWDIR}/astpp
chown -Rf www-data.www-data ${ASTPP_SOURCE_DIR}/web_interface/astpp
chmod -Rf 755 ${WWWDIR}/astpp
sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php/7.4/fpm/php.ini
sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php/7.4/fpm/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php/7.4/fpm/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php/7.4/fpm/php.ini
sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php/7.4/fpm/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.4/fpm/php.ini
systemctl restart php7.4-fpm

fi

CRONPATH='/var/spool/cron/crontabs/astpp'

echo "# To call all crons
* * * * * cd ${ASTPP_SOURCE_DIR}/web_interface/astpp/cron/ && php cron.php crons
" > $CRONPATH
chmod 600 $CRONPATH
crontab $CRONPATH
touch /var/log/astpp/astpp.log
touch /var/log/astpp/astpp_email.log
chmod -Rf 755 $ASTPP_SOURCE_DIR
chmod 777 /var/log/astpp/astpp.log
chmod 777 /var/log/astpp/astpp_email.log
sed -i "s#dbpass = <PASSSWORD>#dbpass = ${ASTPPUSER_MYSQL_PASSWORD}#g" ${ASTPPDIR}astpp-config.conf
sed -i "s#DB_PASSWD=\"<PASSSWORD>\"#DB_PASSWD = \"${ASTPPUSER_MYSQL_PASSWORD}\"#g" ${ASTPPDIR}astpp.lua
sed -i "s#base_url=https://localhost:443/#base_url=https://${ASTPP_HOST_DOMAIN_NAME}/#g" ${ASTPPDIR}/astpp-config.conf
sed -i "s#PASSWORD = <PASSWORD>#PASSWORD = ${ASTPPUSER_MYSQL_PASSWORD}#g" /etc/odbc.ini

#Make changes for ASTPP to use php7.4-fpm in Debian 11 

if [ ."$os_codename" = ."bullseye" ]; then
sed -i -e 's!fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;!fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;!g' /etc/nginx/conf.d/fs.conf
printf '%s\n'  'g/^/s|fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;|fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;|g' 'w' 'q' | ed -s /etc/nginx/conf.d/astpp.conf
fi

systemctl restart nginx
} #end normalize_astpp





install_database ()
{


        mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} create ${ASTPP_DATABASE_NAME}
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER 'astppuser'@'localhost' IDENTIFIED BY '${ASTPPUSER_MYSQL_PASSWORD}';"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "ALTER USER 'astppuser'@'localhost' IDENTIFIED BY '${ASTPPUSER_MYSQL_PASSWORD}';"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON \`${ASTPP_DATABASE_NAME}\` . * TO 'astppuser'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"

        #Need to make modifications to .sql file for compatibility with MariaDB
        printf '%s\n' 'g/^/s|\(/\*!50003 SET collation_connection  = \)utf8mb4_0900_ai_ci\( \*/ ;\)|\1utf8mb4_unicode_520_ci\2|g' 'w' 'q' | ed -s ${ASTPP_SOURCE_DIR}/database/astpp-5.0.sql
        printf '%s\n' 'g/^/s|\(/\*!50001 SET collation_connection      = \)utf8mb4_0900_ai_ci\( \*/;\)|\1utf8mb4_unicode_520_ci\2|g' 'w' 'q' | ed -s ${ASTPP_SOURCE_DIR}/database/astpp-5.0.sql

        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-5.0.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-5.0.1.sql

} #end install_database


#Firewall Configuration
configure_firewall()
{

apt install -y firewalld
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-port=5060/udp
firewall-cmd --permanent --zone=public --add-port=5060/tcp
firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
firewall-cmd --reload
} #end configure_firewall



#Install Monit for service monitoring
install_monit ()
{


#Monit is not is Buster Backports

apt install -t buster-backports monit -y 

read -p "Enter a Notification email address for sytem monitor: ${EMAIL}"

if [ ."$os_codename" = ."buster" ]; then
apt-get -y install monit
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monit/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL/etc/monit/monitrc
sed -i -e 's/##   subject: monit alert on --  $EVENT $SERVICE/   subject: monit alert --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monit/monitrc
sed -i -e 's/## }/ }/g' /etc/monit/monitrc
echo '
#------------MySQL
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
    start program = "/bin/systemctl start mariadb"
    stop program = "/bin/systemctl stop mariadb"
if failed host 127.0.0.1 port 3306 then restart
if 5 restarts within 5 cycles then timeout

#------------Fail2ban
check process fail2ban with pidfile /var/run/fail2ban/fail2ban.pid
    start program = "/bin/systemctl start fail2ban"
    stop program = "/bin/systemctl stop fail2ban"

# ---- FreeSWITCH ----
check process freeswitch with pidfile /var/run/freeswitch/freeswitch.pid
    start program = "/bin/systemctl start freeswitch"
    stop program  = "/bin/systemctl stop freeswitch"

#-------nginx----------------------
check process nginx with pidfile /var/run/nginx.pid
    start program = "/bin/systemctl start nginx" with timeout 30 seconds
    stop program  = "/bin/systemctl stop nginx"

#-------php-fpm----------------------
check process php7.3-fpm with pidfile /var/run/php/php7.3-fpm.pid
    start program = "/bin/systemctl start php7.3-fpm" with timeout 30 seconds
    stop program  = "/bin/systemctl stop php7.3-fpm"

#--------system
check system localhost
    if loadavg (5min) > 8 for 4 cycles then alert
    if loadavg (15min) > 8 for 4 cycles then alert
    if memory usage > 80% for 4 cycles then alert
    if swap usage > 20% for 4 cycles then alert
    if cpu usage (user) > 80% for 4 cycles then alert
    if cpu usage (system) > 20% for 4 cycles then alert
    if cpu usage (wait) > 20% for 4 cycles then alert

check filesystem "root" with path /
    if space usage > 80% for 1 cycles then alert' >> /etc/monit/monitrc

systemctl restart monit
systemctl enable monit


elif [ ."$os_codename" = ."bullseye" ]; then
apt-get -y install monit
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monit/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert on --  $EVENT $SERVICE/   subject: monit alert --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monit/monitrc
sed -i -e 's/## }/ }/g' /etc/monit/monitrc
echo '
#------------MySQL
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
    start program = "/bin/systemctl start mariadb"
    stop program = "/bin/systemctl stop mariadb"
if failed host 127.0.0.1 port 3306 then restart
if 5 restarts within 5 cycles then timeout

#------------Fail2ban
check process fail2ban with pidfile /var/run/fail2ban/fail2ban.pid
    start program = "/bin/systemctl start fail2ban"
    stop program = "/bin/systemctl stop fail2ban"

# ---- FreeSWITCH ----
check process freeswitch with pidfile /var/run/freeswitch/freeswitch.pid
    start program = "/bin/systemctl start freeswitch"
    stop program  = "/bin/systemctl stop freeswitch"

#-------nginx----------------------
check process nginx with pidfile /var/run/nginx.pid
    start program = "/bin/systemctl start nginx" with timeout 30 seconds
    stop program  = "/bin/systemctl stop nginx"

#-------php-fpm----------------------
check process php7.4-fpm with pidfile /var/run/php/php7.4-fpm.pid
    start program = "/bin/systemctl start php7.4-fpm" with timeout 30 seconds
    stop program  = "/bin/systemctl stop php7.4-fpm"

#--------system
check system localhost
    if loadavg (5min) > 8 for 4 cycles then alert
    if loadavg (15min) > 8 for 4 cycles then alert
    if memory usage > 80% for 4 cycles then alert
    if swap usage > 20% for 4 cycles then alert
    if cpu usage (user) > 80% for 4 cycles then alert
    if cpu usage (system) > 20% for 4 cycles then alert
    if cpu usage (wait) > 20% for 4 cycles then alert

check filesystem "root" with path /
    if space usage > 80% for 1 cycles then alert' >> /etc/monit/monitrc


systemctl restart monit
systemctl enable monit

fi



} #End of Monit


#Configure logrotation for maintain log size
logrotate_install ()
{


if [ ."$os_codename" = ."buster" ]; then
sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog
sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/php7.3-fpm
sed -i -e 's/rotate 12/rotate 5/g' /etc/logrotate.d/php7.3-fpm
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/nginx
sed -i -e 's/rotate 52/rotate 5/g' /etc/logrotate.d/nginx
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit


elif [ ."$os_codename" = ."bullseye" ]; then
sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog

sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/php7.4-fpm
sed -i -e 's/rotate 12/rotate 5/g' /etc/logrotate.d/php7.4-fpm
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/nginx
sed -i -e 's/rotate 52/rotate 5/g' /etc/logrotate.d/nginx
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit

fi




}




#Remove all downloaded and temp files from server
clean_server ()
{
        cd /usr/src
#        rm -Rf libks
#        rm -Rf spansp
#        rm -Rf sofia-sip-1.13.7
#        rm -Rf freeswitch-$switch_version.-release

        echo "FS restarting...!"
        systemctl restart freeswitch
        echo "FS restarted...!"
}


#Installation Information Print
start_installation ()
{

	introduction
	MYSQL_ROOT_PASSWORD=`echo "$(genpasswd 20)" | sed s/./*/5`
        ASTPPUSER_MYSQL_PASSWORD=`echo "$(genpasswd 20)" | sed s/./*/5`

        ## Just making sure password is generated
        echo $MYSQL_ROOT_PASSWORD
        echo $ASTPPUSER_MYSQL_PASSWORD

        pre_install
        install_prerequisties
        get_user_response
	os_dependencies
        freeswitch_source_dependencies
	install_freeswitch
        get_astpp_source
        normalize_mariadb
        install_database
        normalize_freeswitch
        install_astpp
        normalize_astpp
        configure_firewall
        install_fail2ban
        install_monit
        logrotate_install
        clean_server

        clear
        echo "******************************************************************************************"
        echo "******************************************************************************************"
        echo "******************************************************************************************"
        echo "**********                                                                      **********"
        echo "**********           Your ASTPP is installed successfully                       **********"
        echo "                     Browse URL: https://${ASTPP_HOST_DOMAIN_NAME}"
        echo "                     Username: admin"
        echo "                     Password: admin"
        echo ""
        echo "                     MySQL root user password:"
        echo "                     ${MYSQL_ROOT_PASSWORD}"
        echo ""
        echo "                     MySQL astppuser password:"
        echo "                     ${ASTPPUSER_MYSQL_PASSWORD}"
        echo ""
        echo "**********           IMPORTANT NOTE: Please reboot your server once.            **********"
        echo "**********                                                                      **********"
        echo "******************************************************************************************"
        echo "******************************************************************************************"
        echo "******************************************************************************************"
}
start_installation




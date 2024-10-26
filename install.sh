#!/bin/bash

PORT=8080
HOME_HAPROXY_WI=haproxy-wi

echo "Choose DB: (1)Sqlite or (2)Mysql? Default: Sqlite"
read DB

if [[ $DB == 2 ]];then
   echo "Mysql server is (1)remote  or (2)local?"
   read REMOTE
   if [[ $REMOTE == 1 ]];then
        echo "Enter IP remote Mysql server"
        read IP
   else
        MINSTALL=1
   fi
fi
echo "Choose Haproxy-WI port. Default: [$PORT]"
read CHPORT
echo "Enter Haproxy-wi home dir. Default: /var/www/[$HOME_HAPROXY_WI]"
read CHHOME_HAPROXY

if [[ -z $HAPROXY ]];then	
	HAPROXY="no"
fi

if [[ -n $CHPORT ]];then
        PORT=$CHPORT
fi
if [[ -n "$CHHOME_HAPROXY" ]];then
        HOME_HAPROXY_WI=$CHHOME_HAPROXY
fi

echo -e "\n###########################################################"
echo -e "# Installing Required Software ...."
echo -e "###########################################################"

if hash apt-get 2>/dev/null; then
	apt-get install git net-tools lshw dos2unix gcc g++ netcat-openbsd freetype2-demos libatlas-base-dev ldap-utils libldap-dev libldap2 libldap2-dev libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev libssl-dev apache2 libapache2-mod-uwsgi libapache2-mod-proxy-uwsgi apache2-utils python3 python3-dev python3-pip -y
	HTTPD_CONFIG="/etc/apache2/apache2.conf"
	HAPROXY_WI_VHOST_CONF="/etc/apache2/sites-enabled/haproxy-wi.conf"
	HTTPD_NAME="apache2"
	HTTPD_PORTS="/etc/apache2/ports.conf"
	
	if [[ $MINSTALL == 1 ]];then
		apt-get install software-properties-common mariadb-server mariadb-client -y
	fi
fi
 
echo -e "\n###########################################################"
echo -e "# Updating Apache config and Configuring Virtual Host"
echo -e "#"

sudo sed -i "0,/^Listen .*/s//Listen $PORT/" $HTTPD_PORTS

echo -e "# Checking for Apache Vhost config"

sudo touch $HAPROXY_WI_VHOST_CONF
/bin/cat $HAPROXY_WI_VHOST_CONF

if [ $? -eq 1 ]
then

	echo "# Didnt Sense exisitng installation Proceeding ...."
	echo -e "###########################################################"
	exit 1

else
	echo -e "# Creating VirtualHost for Apache"
 
cat << EOF > $HAPROXY_WI_VHOST_CONF
<VirtualHost *:$PORT>
        SSLEngine on
        SSLCertificateFile /var/www/haproxy-wi/app/certs/haproxy-wi.crt
        SSLCertificateKeyFile /var/www/haproxy-wi/app/certs/haproxy-wi.key

        ServerName haprox-wi.example.com
        ErrorLog /var/log/httpd/haproxy-wi.error.log
        CustomLog /var/log/httpd/haproxy-wi.access.log combined
		TimeOut 600
		LimitRequestLine 16380

        DocumentRoot /var/www/$HOME_HAPROXY_WI
        ScriptAlias /cgi-bin/ "/var/www/$HOME_HAPROXY_WI/app/"


        <Directory /var/www/$HOME_HAPROXY_WI/app>
                Options +ExecCGI
                AddHandler cgi-script .py
                Order deny,allow
                Allow from all
        </Directory>
		
		<FilesMatch "\.config$">
                Order Deny,Allow
                Deny from all
        </FilesMatch>
</VirtualHost>
EOF
	echo -e "###########################################################"
fi 

echo -e "\n###########################################################"
echo -e "# Creating Checker HAproxy Service ...."
echo -e "###########################################################"
cat << EOF > /etc/systemd/system/multi-user.target.wants/checker_haproxy.service
[Unit]
Description=Haproxy backends state checker
After=syslog.target network.target

[Service]
Type=simple
WorkingDirectory=/var/www/$HOME_HAPROXY_WI/app/
ExecStart=/var/www/$HOME_HAPROXY_WI/app/tools/checker_master.py

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=checker

RestartSec=2s
Restart=on-failure
TimeoutStopSec=1s

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/rsyslog.d/checker.conf 
if $programname startswith 'checker' then /var/www/__HOME_HAPROXY_WI__/log/checker-error.log
& stop
EOF
sed -i -e "s/__HOME_HAPROXY_WI__/$HOME_HAPROXY_WI/g" /etc/rsyslog.d/checker.conf 

cat << EOF > /etc/logrotate.d/checker
/var/www/$HOME_HAPROXY_WI/log/checker-error.log {
    daily
    rotate 10
    missingok
    notifempty
	create 0644 apache apache
	dateext
    sharedscripts
}
EOF

echo -e "\n###########################################################"
echo -e "# Creating Metrics HAproxy Service ...."
echo -e "###########################################################"

cat << EOF > /etc/systemd/system/multi-user.target.wants/metrics_haproxy.service
[Unit]
Description=Haproxy metrics
After=syslog.target network.target

[Service]
Type=simple
WorkingDirectory=/var/www/$HOME_HAPROXY_WI/app/
ExecStart=/var/www/$HOME_HAPROXY_WI/app/tools/metrics_master.py

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=metrics

RestartSec=2s
Restart=on-failure
TimeoutStopSec=1s

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/rsyslog.d/metrics.conf 
if $programname startswith 'metrics' then /var/www/__HOME_HAPROXY_WI__/log/metrics-error.log
& stop
EOF
sed -i -e "s/__HOME_HAPROXY_WI__/$HOME_HAPROXY_WI/g" /etc/rsyslog.d/metrics.conf

cat << EOF > /etc/logrotate.d/metrics
/var/www/$HOME_HAPROXY_WI/log/metrics-error.log {
    daily
    rotate 10
    missingok
    notifempty
	create 0644 apache apache
	dateext
    sharedscripts
}
EOF

echo -e "\n###########################################################"
echo -e "# Creating Keep Alive HAproxy Service ...."
echo -e "###########################################################"

cat << EOF > /etc/systemd/system/keep_alive.service
[Unit]
Description=Keep Alive Haproxy 
After=syslog.target network.target

[Service]
Type=simple
WorkingDirectory=/var/www/$HOME_HAPROXY_WI/app/
ExecStart=/var/www/$HOME_HAPROXY_WI/app/tools/keep_alive.py

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=keep_alive

RestartSec=2s
Restart=on-failure
TimeoutStopSec=1s

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/rsyslog.d/keep_alive.conf 
if $programname startswith 'keep_alive' then /var/www/__HOME_HAPROXY_WI__/log/keep_alive.log
& stop
EOF
sed -i -e "s/__HOME_HAPROXY_WI__/$HOME_HAPROXY_WI/g" /etc/rsyslog.d/keep_alive.conf

cat << EOF > /etc/logrotate.d/metrics
/var/www/$HOME_HAPROXY_WI/log/keep_alive.log {
    daily
    rotate 10
    missingok
    notifempty
	create 0644 apache apache
	dateext
    sharedscripts
}
EOF

sed -i 's/#$UDPServerRun 514/$UDPServerRun 514/g' /etc/rsyslog.conf
sed -i 's/#$ModLoad imudp/$ModLoad imudp/g' /etc/rsyslog.conf

echo -e "\n###########################################################"
echo -e "# Activate HAproxy Services ...."
echo -e "###########################################################"

systemctl daemon-reload      
systemctl restart logrotate
systemctl restart rsyslog
systemctl restart metrics_haproxy.service
systemctl restart checker_haproxy.service
systemctl restart keep_alive.service
systemctl enable metrics_haproxy.service
systemctl enable checker_haproxy.service
systemctl enable keep_alive.service

if hash apt-get 2>/dev/null; then
	sed -i 's|/var/log/httpd/|/var/log/apache2/|g' $HAPROXY_WI_VHOST_CONF
	cd /etc/apache2/mods-enabled
	sudo ln -s ../mods-available/cgi.load
fi

echo -e "\n###########################################################"
echo -e "# Testing config ...."
/usr/sbin/apachectl configtest 

if [ $? -eq 1 ]
then
	echo -e "# apache Configuration Has failed, Please verify Apache Config"
	exit 1
fi
echo -e "###########################################################"

echo -e "\n###########################################################"
echo -e "# Getting Latest software from The repository."

/usr/bin/git clone https://github.com/rezgui/haproxy-wi.git /var/www/$HOME_HAPROXY_WI

if [ $? -eq 1 ]
then
   echo -e "# Unable to clone The repository Please check connetivity to Github"
   exit 1
fi
echo -e "###########################################################"

echo -e "\n###########################################################"
echo -e "# Installing required Python Packages"
sudo -H pip3 install --upgrade pip
sudo pip3 install -r /var/www/$HOME_HAPROXY_WI/requirements.txt

if [ $? -eq 1 ]
then
   echo "# Unable to install Required Packages, Please check Pip error log and Fix the errors and Rerun the script"
   exit 1
else 
	echo -e "# Installation Succesful"
	echo -e "###########################################################"
fi

if [[ $MINSTALL = 1 ]];then
	echo -e "\n###########################################################"
	echo -e "# starting Databse and applying config"
	systemctl enable mariadb
	systemctl start mariadb

	if [ $? -eq 1 ]
	then
		echo "# Can't start Mariadb"
	echo -e "###########################################################"
		exit 1
	fi

	if [ $? -eq 1 ]
	then
		echo "# Unable to start Mariadb Service Please check logs"
	echo -e "###########################################################"
		exit 1
	else 

		mysql -u root -e "create database haproxywi";
		mysql -u root -e "grant all on haproxywi.* to 'haproxy-wi'@'%' IDENTIFIED BY 'haproxy-wi';"
		mysql -u root -e "grant all on haproxywi.* to 'haproxy-wi'@'localhost' IDENTIFIED BY 'haproxy-wi';"
		mysql -u root -e "flush privileges;"
  
		echo -e "Databse has been created Succesfully and User permissions added"
  fi
fi


if [[ $DB == 2 ]];then
	echo -e "# Setting Application to use Mysql As a backend"
	sed -i '0,/enable = 0/s//enable = 1/' /var/www/$HOME_HAPROXY_WI/app/haproxy-wi.cfg
fi

if [[ -n $IP ]];then
	echo -e "# Setting Local or Remote to use Mysql As a backend"
	sed -i "0,/mysql_host = 127.0.0.1/s//mysql_host = $IP/" /var/www/$HOME_HAPROXY_WI/app/haproxy-wi.cfg
fi
echo -e "###########################################################"

echo -e "\n###########################################################"
echo -e "# Starting Services"

systemctl enable $HTTPD_NAME; systemctl restart $HTTPD_NAME

if [ $? -eq 1 ]
then
	echo "Services Has Not  been started, Please check error logs"
	echo -e "###########################################################"

else 
	echo -e "Services have been started, "
 	echo -e "Please Evaluate the tool by adding a host / DNS ectry for /etc/hosts file."
 	echo -e "This can be done by adding an exemple entry like this :"
	echo -e "192.168.1.100 haprox-wi.example.com"
	echo -e "###########################################################"

fi 

sed -i "s|^fullpath = .*|fullpath = /var/www/$HOME_HAPROXY_WI|g" /var/www/$HOME_HAPROXY_WI/app/haproxy-wi.cfg
sudo mkdir /var/www/$HOME_HAPROXY_WI/app/certs
sudo mkdir /var/www/$HOME_HAPROXY_WI/keys
sudo mkdir /var/www/$HOME_HAPROXY_WI/configs/
sudo mkdir /var/www/$HOME_HAPROXY_WI/configs/hap_config/
sudo mkdir /var/www/$HOME_HAPROXY_WI/configs/kp_config/
sudo mkdir /var/www/$HOME_HAPROXY_WI/log/
sudo sudo chmod +x /var/www/$HOME_HAPROXY_WI/app/*.py
sudo chmod +x /var/www/$HOME_HAPROXY_WI/app/tools/*.py
chmod +x /var/www/$HOME_HAPROXY_WI/update.sh


cd /var/www/$HOME_HAPROXY_WI/app
./create_db.py
if hash apt-get 2>/dev/null; then
	sudo chown -R www-data:www-data /var/www/$HOME_HAPROXY_WI/
	sudo chown -R www-data:www-data /var/log/apache2/
else
	sudo chown -R apache:apache /var/www/$HOME_HAPROXY_WI/
	sudo chown -R apache:apache /var/log/httpd/
fi

echo -e "\n###########################################################"
echo -e "# Thank You for Evaluating Haproxy-wi"
echo -e "###########################################################"

exit 0

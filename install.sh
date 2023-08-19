#/bin/bash
#install.sh
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

#function to print with color
function printc {
    printf "${1}=================================\n"
    printf "${2}\n"
    printf "=================================\n${NC}"
}

# if [[ $(/usr/bin/id -u) -ne 0 ]]; then
#     printc $RED "This script must be run as root";
#     exit
# fi

# do not run this script as root
if [[ $(/usr/bin/id -u) -eq 0 ]]; then
    printc $RED "This script must not be run as root";
    exit
fi

# openingmessage=""
# openingmessage+="Pada saat proses install, jika muncul layar ungu langsung tekan enter aja\ndan mungkin akan muncul beberapa kali\n\n"
# openingmessage+="Karena proses install ini membutuhkan waktu yang cukup lama,\nada kemungkinan untuk memasukkan password sudo kembali"
# printc $YELLOW "$openingmessage"
# echo ''
username=$USER

#PROMPT START
printc $GREEN "Enter new mysql username:"
read mysqlusername # change this to what you want for your mysql username
printc $GREEN "Enter new mysql password:"
read mysqlpassword # change this to what you want for your mysql password and master password
printc $GREEN "Do you want to use nginx or apache2? (1 for nginx, 2 for apache2)"
read webserver # change this to what you want for your mysql password and master password
printc $GREEN "Enter PHP version (default 8.2):"
read phpversion # change this to what you want for your mysql password and master password
#if php version is empty, then set it to 8.2
if [ -z "$phpversion" ]; then
    phpversion=8.2
fi
printc $GREEN "Do you want to install composer? (1 for yes, 2 for no)"
read composer # change this to what you want for your mysql password and master password
printc $GREEN "Do you want to install redis? (1 for yes, 2 for no)"
read redis # change this to what you want for your mysql password and master password
printc $GREEN "Do you want to install phpmyadmin? (1 for yes, 2 for no)"
read phpmyadmin # change this to what you want for your mysql password and master password
#PROMPT END

sudo apt install -y lsb-release curl gpg software-properties-common
sudo add-apt-repository --yes ppa:ondrej/php

installercommand="unzip"
#install php
installercommand+=" php${phpversion} php${phpversion}-mysql php${phpversion}-mcrypt php${phpversion}-curl php${phpversion}-apcu php${phpversion}-gd php${phpversion}-xml php${phpversion}-bcmath php${phpversion}-zip php${phpversion}-calendar php${phpversion}-dom php${phpversion}-mbstring"
#convert phpversion to float
phpversionfloat=$(echo $phpversion | awk '{print $1+0}')
#if php version less than "8.0", then install php-json
if [ $phpversionfloat -lt 8.0 ]; then
    installercommand+=" php${phpversion}-json"
fi

#if webserver is 1, then use nginx and php-fpm else use apache2 and libapache2-mod-php and php-cgi
if [ $webserver -eq 1 ]; then
    installercommand+=" nginx php${phpversion}-fpm"
else
    installercommand+=" apache2 libapache2-mod-php${phpversion} php${phpversion}-cgi"
fi

#install mysql
installercommand+=" mysql-server"

#install redis
if [ $redis -eq 1 ]; then
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

    installercommand+=" redis php${phpversion}-redis"
fi


sudo apt update
sudo apt-get install -y $installercommand

#install composer
if [ $composer -eq 1 ]; then
    sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    sudo php -r "if (hash_file('sha384', 'composer-setup.php') === 'e21205b207c3ff031906575712edab6f13eb0b361f2085f1f1237b7126d785e826a450292b6cfd1d64d92e6563bbde02') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    sudo php composer-setup.php
    sudo php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/local/bin/composer
fi

#install phpmyadmin
if [ $phpmyadmin -eq 1 ]; then
    cd /var/www
    sudo wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
    sudo unzip phpMyAdmin-5.2.1-all-languages.zip
    sudo mv phpMyAdmin-5.2.1-all-languages phpmyadmin
    sudo rm phpMyAdmin-5.2.1-all-languages.zip
    cd /var/www/phpmyadmin
    sudo mkdir tmp
    cd /var/www
    sudo sudo chown -R www-data:www-data phpmyadmin
    cd /var/www/phpmyadmin
    #blowfish secret 32 character
    blowfishsecret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    #open config.inc.php
    configfile=$(cat config.sample.inc.php)
    configfile="${configfile//"['blowfish_secret'] = ''"/"['blowfish_secret'] = sodium_hex2bin('f16ce59f45714194371b48fe362072dc3b019da7861558cd4ad29e4d6fb13851')"}"
    echo "$configfile" | sudo tee config.inc.php

    #register domain to hosts phpmyadmin.test
    echo "127.0.0.1       phpmyadmin.test" | sudo tee -a /etc/hosts

    #create virtual host for phpmyadmin use nginx or apache2
    if [ $webserver -eq 1 ]; then
        #rm /etc/nginx/sites-available/phpmyadmin.test if exists
        if [ -f "/etc/nginx/sites-available/phpmyadmin.test" ]; then
            sudo rm /etc/nginx/sites-available/phpmyadmin.test
        fi
        sudo touch /etc/nginx/sites-available/phpmyadmin.test
        sudo chmod 777 /etc/nginx/sites-available/phpmyadmin.test
        echo "server {" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    listen 80;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    listen [::]:80;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    root /var/www/phpmyadmin;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    index index.php index.html index.htm index.nginx-debian.html;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    server_name phpmyadmin.test;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    location / {" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "        try_files \$uri \$uri/ =404;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    }" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    location ~ \.php\$ {" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "        include snippets/fastcgi-php.conf;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "        fastcgi_pass unix:/run/php/php${phpversion}-fpm.sock;" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "    }" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        echo "}" | sudo tee -a /etc/nginx/sites-available/phpmyadmin.test
        sudo ln -s /etc/nginx/sites-available/phpmyadmin.test /etc/nginx/sites-enabled/

        #restart nginx
        sudo service nginx restart
    else
        # rm /etc/apache2/sites-available/phpmyadmin.test.conf if exists
        if [ -f "/etc/apache2/sites-available/phpmyadmin.test.conf" ]; then
            sudo rm /etc/apache2/sites-available/phpmyadmin.test.conf
        fi
        sudo touch /etc/apache2/sites-available/phpmyadmin.test.conf
        sudo chmod 777 /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "<VirtualHost *:80>" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "    ServerAdmin webmaster@localhost" | sudo tee -a /etc/apache2/sites
        echo "    DocumentRoot /var/www/phpmyadmin" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "    ServerName phpmyadmin.test" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "    ServerAlias www.phpmyadmin.test" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "    ErrorLog ${APACHE_LOG_DIR}/error.log" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "    CustomLog ${APACHE_LOG_DIR}/access.log combined" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        echo "</VirtualHost>" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.test.conf
        sudo a2ensite phpmyadmin.test.conf

        #enable mod_rewrite
        sudo a2enmod rewrite

        #restart apache2
        sudo service apache2 restart

    fi
fi

sudo mysql -u root -e "CREATE USER '$mysqlusername'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysqlpassword';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$mysqlusername'@'localhost' WITH GRANT OPTION;"
sudo mysql -u root -e "FLUSH PRIVILEGES;"
echo 'sql-mode="NO_ENGINE_SUBSTITUTION"' | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'default_authentication_plugin=mysql_native_password' | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
#restart webserver
if [ $webserver -eq 1 ]; then
    sudo ufw allow 'Nginx HTTP'
    sudo service nginx restart
else
    sudo service apache2 restart
fi
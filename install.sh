#!/bin/bash

#----------------------------------------README.me-----------------------------------------------------------------------------#
### DESCRIPTION ###
#
# Script d'installation guidée et simplifiée de la solution Bareos sur un serveur Debian 11 (uniquement).
# Merci de verifier les versions de bareos disponibles en fonction de cette distribution:
# https://download.bareos.org/bareos/release/Debian_11
#
###Auteurs & version###
#
# Bareos (docs.bareos.org)
# Jérémy BAGES et Fred https://memo-linux.com V-2022.08.02
#
###Licence###
#
#WTFPL : https://fr.wikipedia.org/wiki/WTFPL
#
#----------------------------------------------PARAMETRES PAR DEFAUT-------------------------------------------------------------#

# ATTENTION : Ces parametres sont reglés par defaut pour une installation sur Debian_11 utilisant PHP7.4 et la derniere version en date de Bareos (v.21)
# Toutes modifications de ce script est à vos risques et périls.

RELEASE=release/21

PHP=7.4

URL=https://download.bareos.org/bareos/$RELEASE/Debian_11


#-------------------------------------------------DEBUT DU SCRIPT----------------------------------------------------------------#

# Installation de whiptail pour l'installation via box
apt install whiptail -y


# Confirmation de l'installation

if (whiptail --title "Installation de Bareos" --yesno "Bienvenue sur le programme d'installation guidée de Bareos. Compatible uniquement pour Debian 11. \nSouhaitez-vous procéder à l'installation ?" 0 0); then

# Mise en place du proxy pour Wget

PROXY=$(cat /etc/apt/apt.conf | grep -o -P '(?<=http://).*(?=/")')
PRESENCEAPT=/etc/apt/apt.conf

if test -f "$PRESENCEAPT"; then
sed -i "s\#https_proxy = http://proxy.yoyodyne.com:18023/\https_proxy = http://$PROXY/\g" /etc/wgetrc
sed -i "s\#http_proxy = http://proxy.yoyodyne.com:18023/\http_proxy = http://$PROXY/\g" /etc/wgetrc
sed -i "s\#ftp_proxy = http://proxy.yoyodyne.com:18023/\ftp_proxy = http://$PROXY/\g" /etc/wgetrc
sed -i "s\#use_proxy = on\use_proxy = on\g" /etc/wgetrc
fi


# -PSQL-
#############################################

while :
do
PASSWORD_DB1=$(whiptail --passwordbox "Merci de renseigner le mot de passe pour l'utilsateur postgres (Super-Admin des bases de données)" 8 78 --title "Mot de passe PSQL" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo
else
    whiptail --title "Erreur" --msgbox "Annulation de l'installation." 8 78
exit
fi

#####

PASSWORD_DB2=$(whiptail --passwordbox "Confirmation du mot de passe pour postgres (Super-Admin des bases de données)" 8 78 --title "Confirmation mot de passe PSQL" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo
else
    whiptail --title "Erreur" --msgbox "Annulation de l'installation." 8 78
exit
fi

#### Check des 2 MDP

if [ "$PASSWORD_DB1" = "$PASSWORD_DB2" ]
    then

    # Tout est bon
    whiptail --title "OK" --msgbox "Les mots de passe correspondent. Appuyer sur Entrer pour continuer" 8 78

    break;

    fi
    # Pas les memes valeurs
    whiptail --title "Erreur" --msgbox "Les mots de passe ne correspondent pas, merci de recommencer." 8 78

done


# -BAREOS-
#############################################

while :
do

PASSWORD_BAREOS1=$(whiptail --passwordbox "Merci de renseigner un mot de passe pour l'utilisateur admin de Bareos Web-UI \nCaractères interdits: ; et @ " 9 78 --title "Mot de passe admin BAREOS" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo
else
    whiptail --title "Erreur" --msgbox "Annulation de l'installation." 8 78
exit
fi

#####

PASSWORD_BAREOS2=$(whiptail --passwordbox "Confirmation du mot de passe pour l'utilsateur admin de Bareos Web-ui " 8 78 --title "Confirmation mot de passe BAREOS" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo
else
    whiptail --title "Erreur" --msgbox "Annulation de l'installation." 8 78
exit
fi

#### Check des 2 MDP

if [ "$PASSWORD_BAREOS1" = "$PASSWORD_BAREOS2" ]
    then

    # Tout est bon
    whiptail --title "OK" --msgbox "Les mots de passe correspondent. Appuyer sur Entrer pour continuer" 8 78

    break;

    fi
    # Pas les memes valeurs
    whiptail --title "Erreur" --msgbox "Les mots de passe ne correspondent pas, merci de recommencer." 8 78

done

#############################################


# Suite du script

echo ""
echo "###########################"
echo "Installation d'Apache2"
apt install apache2 -y
sleep 1

echo ""
echo "###########################"
echo "Installation du paquet gnupg"
apt install gnupg -y
sleep 1

echo ""
echo "###########################"
echo "Installation de PHP"
apt install php$PHP -y
sleep 1

echo ""
echo "###########################"
echo "Ajout du dépôt Bareos"
wget -O /etc/apt/sources.list.d/bareos.list $URL/bareos.list
sleep 1

echo ""
echo "###########################"
echo "Ajout de la clé Bareos"
wget -q $URL/Release.key -O- | apt-key add -
sleep 1

echo ""
echo "###########################"
echo "Installation de Bareos et de PostgreSQL"
apt update
apt install bareos postgresql bareos-database-postgresql bareos-webui -y
sleep 1

echo ""
echo "###########################"
echo "Liaisons BDD BAREOS <=> PSQL"
su postgres -c /usr/lib/bareos/scripts/create_bareos_databese
su postgres -c /usr/lib/bareos/scripts/make_bareos_tables
su postgres -c /usr/lib/bareos/scripts/grant_bareos_privileges
sleep 1

echo ""
echo "###########################"
echo "Démarrage des services Bareos"
systemctl start bareos-dir
systemctl start bareos-sd
systemctl start bareos-fd
sleep 1

echo ""
echo "###########################"
echo "Installation d'Adminer"
apt install php$PHP-pgsql -y
wget -O /var/www/html/adminer.php https://www.adminer.org/latest.php
chown -R www-data:www-data /var/www/html
sleep 1

echo ""
echo "###########################"
echo "Redémarrage du service Apache2"
systemctl restart apache2

echo ""
echo "###########################"
echo "Ajout et configuration de l'utilisateur admin dans Bareos"
/bin/bconsole << EOD
configure add console name=admin password=$PASSWORD_BAREOS1 profile=webui-admin tlsenable=false
reload
quit
EOD
sleep 1

echo ""
echo "###########################"
echo "Modification du mot de passe de l'utilisateur postgres (requis pour Adminer)"
su postgres << EOD
psql
alter user postgres password '$PASSWORD_DB1'
\q
exit
EOD
sleep 1

echo ""
echo "###########################"
echo "Modification de la méthode d'authentification de l'utilisateur postgres (requis pour Adminer)"
PSQL_PATH=$(find /etc/postgresql/ -name pg_hba.conf)
sed -i "s\local   all             postgres                                peer\local   all             postgres                                md5\g" $PSQL_PATH
sleep 1

echo ""
echo "###########################"
echo "Redémarrage du service postgresql"
systemctl restart postgresql.service
sleep 1


# Message de fin & résumé
IPFINALE=$(hostname -i)
whiptail --title "Rapport" --msgbox "Bareos est désormais installé sur votre système. \n \nVous pouvez accédez à la console Bareos Web-UI via cette adresse :  http://$IPFINALE/bareos-webui \n \nVous pouvez accédez à la gestion de la base de données via cette adresse : http://$IPFINALE/adminer.php" 0 0

echo ""
echo "Installation terminée"
echo ""
echo "##########################################################"
echo ""
echo "Vous pouvez accédez à la console Bareos Web-UI via cette adresse :  http://$IPFINALE/bareos-webui"
echo ""
echo "Vous pouvez accédez à Adminer pour la gestion de la base de données via cette adresse : http://$IPFINALE/adminer.php"
echo ""
echo "##########################################################"
echo ""


#-----------------------------------------------------Fin---------------------------------------------------#

# SI le user à refuser en premier lieu linstalation de Bareos
else
    echo "Annulation de l'installation."
fi

#!/bin/bash
#
#ASD
#by alipoor90@gmail.com
#
#do user really wants to run asd?
me="$(pwd)/$(basename $0)"
while true
do
read -p "do you really want to run asd?(yes or no)" _wanttorunasd ; echo
if [[ $_wanttorunasd = "yes" ]] ; then printf "Starting with ASD...\n\n" && break ; fi
if [[ $_wanttorunasd = "no" ]] ; then printf "Exiting ASD on user request...\n\n" && exit 0 ; fi
done

#----------------------------------substitute firewalld and install iptables----------------------------------
systemctl stop firewalld.service ; systemctl mask firewalld.service
yum -y install iptables-services ; systemctl enable iptables.service
#-------------------------------------------install needed packages-------------------------------------------
yum -y install epel-release
#yum -y install httpd bind perl php postgresql phpPgAdmin vsftpd postfix dovecot openvpn
#-------------------------------------------enable needed services--------------------------------------------
systemctl enable httpd.service
systemctl enable named
#------------------------------------------------edit grub2 config--------------------------------------------
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/' /etc/default/grub
#-------------------------------------------setting hostname and nameservers----------------------------------
_hostname=""
while [[ $_hostname = "" ]]
do
read -p "Please enter hostname (i.e. server.example.com):" _hostname
done
echo $_hostname > /etc/hostname
#Setting nameservers
echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 4.2.2.4\nnameserver 4.2.2.2\n' > /etc/resolv.conf
chattr +i /etc/resolv.conf #prevent rebuild by NetworkManager on boots
################################################### security #################################################
#-------------------------------------------------disable SELINUX---------------------------------------------
while true
do
read -p "Put selinux into permissive mode?(yes or no)" _selinuxmode ; echo
if [[ $_selinuxmode = "yes" ]] ; then sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config ; break ; fi
if [[ $_selinuxmode = "no" ]] ; then break ; fi
done
#---------------------------------------------changing root password------------------------------------------
while true
do
while true
do
read -s -p "Please enter new password for root:" _rootpassword ; echo
read -s -p "Please enter it again:" _rootpassword2 ; echo
[ "$_rootpassword" = "$_rootpassword2" ] && [ "$_rootpassword" != "" ] && break
echo "Entered passwords do not match or empty, please try again ..."
done
passwd --stdin root <<< $_rootpassword
[ "$?" = "0" ] && _rootpassword="" && _rootpassword2="" && break
done
#-----------------------------------------------adding new user----------------------------------------------
while true
do
read -p "Please enter new username:" _username
[ "$_username" = "" ] && continue
while true
do
read -s -p "Please enter password for new user:" _password ; echo
read -s -p "Please enter it again:" _password2 ; echo
[ "$_password" = "$_password2" ] && [ "$_password" != "" ] && break
echo "Entered passwords do not match or empty, please try again ..."
done
useradd -m -p $(openssl passwd -1 $_password) $_username
[ "$?" = "0" ] && _password="" && _password2="" && break
done
echo $_username' ALL=(ALL) ALL' >> /etc/sudoers
echo 'AllowUsers '$_username >> /etc/ssh/sshd_config
#-----------------------------------permit root user to login through ssh?------------------------------------
while true
do
read -p "permit root user to login through ssh?(yes or no)" _permitrootlogin ; echo
if [[ $_permitrootlogin = "no" ]]
then
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
break
fi
if [[ $_permitrootlogin = "yes" ]]
then
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'AllowUsers root' >> /etc/ssh/sshd_config
break
fi
done
#----------------------------------------------change ssh port------------------------------------------------
echo 'Protocol 2' >> /etc/ssh/sshd_config
read -p "Please enter desired SSH port number or press enter to use 22(default):" _sshport
if [[ $_sshport = "" ]]
then
_sshport="22"
fi
echo 'Port '$_sshport >> /etc/ssh/sshd_config
#-------------------------------------disable all incoming ping requests?-------------------------------------
while true
do
read -p "disable all incoming ping requests?(yes or no)" _icmpechoignoreall ; echo
if [[ $_icmpechoignoreall = "no" ]]
then
break
fi
if [[ $_icmpechoignoreall = "yes" ]]
then
echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all ; echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
break
fi
done
#-----------------------------------------------firewall------------------------------------------------------
systemctl stop iptables.service
iptables -F
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT #http
iptables -A INPUT -p tcp --dport 21 -j ACCEPT #ftp
iptables -I INPUT -p tcp --dport 21000:31000 -j ACCEPT #open ports for ftp passive mode , should add pasv_enable=Yes and pasv_max_port=21000 and pasv_min_port=31000 to /etc/vsftpd/vsftpd.conf (and also good to add chroot_local_user=YES and allow_writeable_chroot=YES and chnage anonymous_enable=YES to anonymous_enable=NO and also do usermod -s /sbin/nologin USERNAME for users only need ftp access)
iptables -A INPUT -p tcp --dport 53 -j ACCEPT #dns
iptables -A INPUT -p udp --dport 53 -j ACCEPT #dns
iptables -A INPUT -p tcp --dport 3306 -j ACCEPT #mysql
iptables -A INPUT -p tcp --dport 25 -j ACCEPT #smtp
iptables -A INPUT -p tcp --dport 143 -j ACCEPT #imap
iptables -A INPUT -p tcp --dport 110 -j ACCEPT #pop3
iptables -A INPUT -p tcp --dport $_sshport -j ACCEPT #for ssh
#iptables -A INPUT -p tcp --dport 22 -j ACCEPT #default ssh port
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A FORWARD -i lo -j ACCEPT
iptables -A FORWARD -o lo -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -P INPUT DROP
iptables-save > /etc/sysconfig/iptables
systemctl start iptables.service
#-----------------------------------remove script file after execution----------------------------------------
rm -f $me #rm -i $me
reboot

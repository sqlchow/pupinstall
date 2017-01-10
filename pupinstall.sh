#!/bin/bash
# Quick script to kickstart puppet installation. Based on https://gist.github.com/mfox/2640568
# Quick and easy script to install Puppet, Facter and dependencies.
# Kickstarts a node ready for puppeting.

# To be tested with:
#   - CentOS 7.0

#Begin - define constants
#-Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

#-Download URI
FACTER_TGZ="http://downloads.puppetlabs.com/facter/facter-2.4.6.tar.gz"
PUPPET_TGZ="http://downloads.puppetlabs.com/puppet/puppet-4.3.2.tar.gz"
#End - define constants

#Begin - helper functions
#subtle diff between builtin and command; check man pages
pushd(){
    builtin pushd "$@" > /dev/null;
}

popd(){
    builtin popd "$@" > /dev/null;
}

exit_with_status(){
    ret="$1"
    msg="command failed with exit code"
    echo -e "\t - ${RED}$msg:${NC} ${YELLOW}$ret${NC}" >&2
    exit $ret
}

ispresent() {
  if [ -f "$1" ]
  then
    # 0 = true
    return 0 
  else
    # 1 = false
    return 1
  fi
}

print_systeminfo(){
    ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/');
    OS=$(lsb_release -i | awk -F':' '{$2=$2;print$2}' | sed 's/^[ \t]*:*//;s/[ \t]*$//');
    VER=$(lsb_release -r | awk -F':' '{$2=$2;print$2}' | sed 's/^[ \t]*:*//;s/[ \t]*$//');
    echo -e "\t -${GREEN}You are working on '$ARCH'-bit '$OS'-'$VER' ${NC}"
}
#Begin - helper functions

#Begin - pre install validations
echo -e "${CYAN}Validating pre-requistes...${NC}"
## Installing Ruby if not present
#echo -e interpret blackslash escapses
echo -e " ${BLUE}1. Checking for Ruby${NC}..."
echo -e "\t Note: ${CYAN}Ruby${NC} should already be installed on the ${GREEN}IACSchool${NC} images.."
if ruby --version > /dev/null 2>&1; then 
    RUB_VER=$(ruby --version | awk -F' ' '{$1=$1;print$1"-" $2}');
    echo -e "\t - ${GREEN}Found Ruby Version:=> ${RUB_VER} ${NC} "
else
    echo -e "\t - ${RED}Ruby not found...${NC}"
    echo -e "\t - ${YELLOW}Installing ruby and related packages...${NC}"
    yum -y -e 0 -d 0 install ruby ruby-devel rubygems libselinux-ruby gcc make;
fi

## Installing lsb_release if not present
echo -e " ${BLUE}2. Checking for yum packages lsb_release, python-docutils...${NC}"
if  ispresent "/usr/bin/lsb_release" ; then
    echo -e "\t -${GREEN}lsb_release found...${NC}"
    print_systeminfo
else
    echo -e "\t - ${RED}lsb_release not found...${NC}"
    echo -e "\t - ${YELLOW}Installing lsb_release and related packages...${NC}"
    yum -y -e 0 -d 0 install redhat-lsb-core;
    if  ispresent "/usr/bin/lsb_release" ; then
        print_systeminfo
    else
        echo -e "\t - ${RED}lsb_release failed to install...${NC}"
    fi
fi

if ispresent "/usr/bin/rst2man" ; then
    echo -e "\t -${GREEN}python-docutils found...${NC}"
else
    echo -e "\t - ${RED}python-docutils not found...${NC}"
    echo -e "\t - ${YELLOW}Installing python-docutils and related packages...${NC}"
    yum -y -e 0 -d 0 install python-docutils;
fi


echo -e " ${BLUE}3. Checking for required gems...${NC}"
#https://serverfault.com/questions/391621/checking-if-a-ruby-gem-is-installed-from-bash-script
if ! gem query -i ruby-shadow > /dev/null 2>&1; then
    echo -e "\t - ${RED}gem 'ruby-shadow' not found...${NC}"
    echo -e "\t - ${YELLOW}Installing 'ruby-shadow' and related packages...${NC}"
    if ! gem install ruby-shadow -q 1>/dev/null; then
        echo -e "\t\t - ${RED}Issues found while installing gem 'ruby-shadow'..."
    else
        echo -e "\t\t - ${GREEN} gem 'ruby-shadow' installed successfully."
    fi
else
    echo -e "\t - ${GREEN}gem 'ruby-shadow' found...${NC}"
fi

if ! gem query -i json_pure > /dev/null 2>&1; then
    echo -e "\t - ${RED}gem 'json_pure' not found...${NC}"
    echo -e "\t - ${YELLOW}Installing 'json_pure' and related packages...${NC}"
    if ! gem install json_pure -q 1>/dev/null; then
        echo -e "\t\t - ${RED}Issues found while installing gem 'json_pure'..."
    else
        echo -e "\t\t - ${GREEN} gem 'json_pure' installed successfully."
    fi
else
    echo -e "\t - ${GREEN}gem 'json_pure' found...${NC}"
fi
echo -e "${CYAN}Finished pre-install validations.${NC}"
#End - pre install validations

echo -e "${CYAN}Starting installation...${NC}"
ret=$(mkdir -p /tmp/{puppet,facter} && echo $?)
if [ $ret == 0 ]; then
    echo -e "\t -${GREEN}Create /tmp/puppet; /tmp/facter ...${NC}"
else
    exit_with_status $ret 
fi

echo -e "    ${CYAN}Downloading Facter...${NC}"
ret=$(curl -s ${FACTER_TGZ} | tar xz -C /tmp/facter --strip-components=1 && echo $?)
if [ $ret == 0 ]; then
    echo -e "\t - ${GREEN}successfully downloaded facter and extracted to '/tmp/facter'${NC}..."
else
    exit_with_status $ret
fi

echo -e "    ${CYAN}Downloading Puppet...${NC}"
ret=$(curl -s ${PUPPET_TGZ} | tar xz -C /tmp/puppet/ --strip-components=1 && echo $?)
if [ $ret == 0 ]; then
    echo -e "\t - ${GREEN}successfully downloaded puppet and extracted to '/tmp/puppet'${NC}..."
else
    exit_with_status $ret
fi

echo -e "    ${CYAN}Creating user Puppet...${NC}"
id puppet 2>1 1>/dev/null
if [[ $? == 1 ]]; then
  adduser -r puppet
fi

## Install Facter
echo -e "    ${CYAN}Installing Facter...${NC}"
pushd /tmp/facter/
ret=$(./install.rb 2>/dev/null && echo $?)
if [ $ret == 0 ]; then
    echo -e "\t - ${GREEN}successfully installed facter...${NC}"
else
    exit_with_status $ret
fi
popd

echo -e "    ${CYAN}Installing hiera...${NC}"
if ! gem query -i hiera > /dev/null 2>&1; then
    echo -e "\t - ${RED}gem 'hiera' not found...${NC}"
    echo -e "\t - ${YELLOW}Installing 'hiera' and related packages...${NC}"
    if ! gem install hiera -q 1>/dev/null; then
        echo -e "\t\t - ${RED}Issues found while installing gem 'hiera'..."
    else
        echo -e "\t\t - ${GREEN} gem 'hiera' installed successfully."
    fi
else
    echo -e "\t - ${GREEN}gem 'hiera' already installed...${NC}"
fi

## Install Puppet
echo -e "    ${CYAN}Installing Puppet...${NC}"
pushd /tmp/puppet/
echo -e "\t - ${BLUE}1.Running puppet install.rb${NC}"
ret=$(./install.rb 2>/dev/null && echo $?)
if [ $ret == 0 ]; then
    echo -e "\t\t - ${GREEN}puppet installer went through...${NC}"
else
    exit_with_status $ret
fi

echo -e "\t - ${BLUE}2.copying config files${NC}"
cp ext/redhat/client.init /etc/init.d/puppet && chmod +x /etc/init.d/puppet
if [[ $? -ne 0 ]]; then
    ret=$?
    echo -e "\t ${RED}Copy client.init failed. Exit code:${NC} ${YELLOW}$ret${NC}" >&2
    exit $ret
fi

cp ext/redhat/client.sysconfig /etc/sysconfig/puppet
if [[ $? -ne 0 ]]; then
    ret=$?
    echo -e "\t ${RED}Copy client.sysconfig failed. Exit code:${NC} ${YELLOW}$ret${NC}" >&2
    exit $ret
fi

cp ext/redhat/logrotate /etc/logrotate.d/puppetmaster
if [[ $? -ne 0 ]]; then
    ret=$?
    echo -e "\t ${RED}Copy logrotate failed. Exit code:${NC} ${YELLOW}$ret${NC}" >&2
    exit $ret
fi

mkdir -p /etc/puppetlabs/puppet
cp conf/puppet.conf /etc/puppetlabs/puppet/
if [[ $? -ne 0 ]]; then
    ret=$?
    echo -e "\t ${RED}Copy puppet.conf failed. Exit code:${NC} ${YELLOW}$ret${NC}" >&2
    exit $ret
fi

echo -e "    ${CYAN}Setting up Puppet service...${NC}"
chkconfig --add puppet
chkconfig puppet on
if [[ $? == 1 ]]; then
    ret=$?
    echo -e "\t ${RED}setting up puppet service failed. Exit code:${NC} ${YELLOW}$ret${NC}" >&2
    exit $ret
fi
popd

echo "
* PRO TIP #1: Configure your Puppet Master in puppet.conf:

  [agent]
  server = puppet-master.yourdomain.co.nz

* PRO TIP #2: Run: 

  puppet agent -v --test --waitforcert 60

..to send a signing request to the Puppet Master.
"
echo -e "${YELLOW}If you have issues with certificates, 'gem install openssl' could be a quick fix...${NC}"

exit
#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37

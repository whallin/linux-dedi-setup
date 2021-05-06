#!/bin/bash

# Placeholders
## Only edit the placeholders in case you know what you're doing.
version=1.0.2
osName="$(. /etc/os-release && echo "$ID")"
osVersion="$(. /etc/os-release && echo "$VERSION_ID")"

# Enable alias support
shopt -s expand_aliases

# Phrases
alias scriptTerminated='error "Script terminated..."'

# Colors
## "heading" is yellow.
heading(){
    echo -e '\e[36m'$1'\e[0m';
}
## "paragraph" is grey.
paragraph() {
	echo -e "\e[90m${1}\e[0m"
}
## "success" is green.
success() {
	echo -e "\e[32m${1}\e[0m"
}
## "error" is red.
error() {
	echo -e "\e[31m${1}\e[0m"
}

# Precheck
preCheck(){
    heading "WISP IP Whitelist v${version}"
    heading "Developed by William Hallin <me@williamhallin.com>"
    echo ""

    # Check if script was run as root
    if [ "$EUID" -ne 0 ]; then
        error "You have to run this script with root privileges."
        scriptTerminated
        exit 126
    fi

    # Print distrubition name and version
    if [ -r /etc/os-release ]; then
        success "/etc/os-release found on system."
        paragraph "You are running ${osName} ${osVersion}"
        echo ""
    else
        error "/etc/os-release not found on system."
        scriptTerminated
        exit 2
    fi

    # Terminate script if user isn't running a supported distro
    if [ $osName == "debian" ] && [ $osName == "ubuntu" ] && [ $osName == "rhel" ] && [ $osName == "centos" ] && [ $osName == "cloudlinux" ] && [ $osName == "fedora" ]; then
        error "You are running an unsupported distribution."
        paragraph "Check the GitHub page for a list of supported distributions."
        scriptTerminated
        exit 126
    fi
}

# Function for getting ports
getPorts(){
    read -a ports
    # Restart the process if user doesn't enter any ports
    if [[ $ports = "" ]]; then
        error "You must enter at least one port, please try again."
        getPorts
    fi
}

# Ask the user for the desired ports
paragraph "Enter the list of ports you want whitelisted. Seperate each by a space."
paragraph "Port 443, 8080, 2022 are used by WISP by default."
paragraph "If you wish to whitelist ports 25565-25570, enter:"
paragraph "25565 25566 25567 25568 25569 25570"

getPorts

# Install firewall and apply rules
if [ $osName == "rhel" ] || [ $osName == "centos" ] || [ $osName == "fedora" ]; then
    yum -y install firewalld wget
    # Allow connections via the default ssh port (22)
    firewall-cmd --add-service=ssh
    # Download the list of WISP IPs (IPv4)
    wget https://cdn.williamhallin.com/wisp-v4
    # Create the firewall rules
    for ips in `cat wisp-v4`;
    do
        for port in "${ports[@]}";
        do
            firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address='"$ips"' port port='"$port"' protocol="tcp" accept'
            # 
            # Comment from <me@williamhallin.com>:
            # I can't actually seem to find a way to replace the "source address"
            # property with something that would whitelist a specific local interface.
            # If someone is more familiar with firewalld, feel free to PR changes to the
            # command below so we can whitelist a full local interface to do connects.
            # 
            # firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address='"$ips"' port port='"$port"' protocol="tcp" accept'
        done
    done
    firewall-cmd --reload
elif [ $osName == "debian" ] || [ $osName == "ubuntu" ]; then
    apt -y install ufw wget
    # Allow connections via the default ssh port (22)
    ufw allow 22
    # Download the list of WISP IPs (IPv4)
    wget https://cdn.williamhallin.com/wisp-v4
    # Create the firewall rules
    for ips in `cat wisp-v4`;
    do
        for port in "${ports[@]}";
        do
            ufw allow from $ips to any proto tcp port $port
            ufw allow in on wisp0 to any proto tcp port $port
        done
    done
    yes | ufw enable
fi

# Remove list of WISP's IPs
paragraph "Removing list of WISP's IPs..."
rm wisp-v4

# Thank you
echo ""
heading "The setup is complete."
echo ""
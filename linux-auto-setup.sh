#!/bin/bash

# Placeholders
## Only edit the placeholders in case you know what you're doing.
version=1.0.4
username="YOUR NAME"
osName="$(. /etc/os-release && echo "$ID")"
osVersion="$(. /etc/os-release && echo "$VERSION_ID")"
#
# Comment from <me@williamhallin.com>:
# I've added these placeholders here if someone ever wants to
# rework the check statements to see if the system has
# compatability with this script or not. It's pretty much only
# there to be if someone want's to minify things later down the
# line.
#
#supportedOS=("debian" "ubuntu" "rhel" "centos" "cloudlinux" "fedora")
#supportedRHEL=("rhel" "centos" "cloudlinux" "fedora")
#supportedDebian=("debian" "ubuntu")

# Enable alias support
shopt -s expand_aliases

# Phrases
alias scriptTerminated='error "Script terminated..."'
alias yesQuestion='heading "[1] Yes"'
alias skipQuestion='heading "[2] No"'
alias userSelectedYes='paragraph "Applying changes..."'
alias userSelectedNo='paragraph "Skipping..."'
alias userNoSelection='error "No valid option provided, retrying..."'

# Colors
## "heading" is yellow.
heading(){
    echo -e '\e[36m'$1'\e[0m';
}
## "paragraph" is grey.
paragraph() {
	echo -e "\e[90m${1}\e[0m";
}
## "success" is green.
success() {
	echo -e "\e[32m${1}\e[0m";
}
## "error" is red.
error() {
	echo -e "\e[31m${1}\e[0m";
}

# Precheck
preCheck(){
    heading "Linux Auto-setup v${version}"
    heading "Developed by Thien Tran <contact@thientran.io>"
    heading "Forked by William Hallin <me@williamhallin.com>"
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
    else
        error "/etc/os-release not found on system."
        scriptTerminated
        exit 2
    fi

    # Terminate script if user isn't running a supported distro
    if [ $osName == "debian" ] && [ $osName == "ubuntu" ] && [ $osName == "rhel" ] && [ $osName == "centos" ] && [ $osName == "cloudlinux" ] && [ $osName == "fedora" ] && [ $osName == "rocky" ]; then
        error "You are running an unsupported distribution."
        paragraph "Check the GitHub page for a list of supported distributions."
        scriptTerminated
        exit 126
    fi
}

# Update and clean un-used packages
updatePackages(){
    echo ""
    paragraph "Updating and removing unused packages, please wait..."
    echo ""
    sleep 3s
    if [ $osName == "rhel" ] || [ $osName == "centos" ] || [ $osName == "cloudlinux" ] || [ $osName == "fedora" ] || [ $osName == "rocky" ]; then
        yum -y upgrade
        yum -y autoremove
        yum -y install curl
    elif [ $osName == "debian" ] || [ $osName == "ubuntu" ]; then
        apt update
        apt -y upgrade
        apt -y autoremove
        apt -y autoclean
        apt -y install curl
    fi
}

# Block ping packets, yes or no?
blockICMP(){
    # Question and description
    echo ""
    heading "Do you want to block ICMP packets?"
    heading "You should keep them enabled [2] if you are using a monitoring system."
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectICMP
    case $selectICMP in
        1 ) userSelectedYes
            /sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP
            (crontab -l ; echo "@reboot /sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP >> /dev/null 2>&1")| crontab -
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            blockICMP
    esac
}

# Add basic iptable rules, yes or no?
basicIPtable(){
    # Question and description
    echo ""
    heading "Do you want to add some iptable rules?"
    heading "The rules have been made by the GitHub user TommyTran732."
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectIptable
    case $selectIptable in
        1 ) userSelectedYes
            curl -sSL https://raw.githubusercontent.com/whallin/linux-dedi-setup/master/linux-basic-iptables.sh | bash
            # Allow connections via the default ssh port (22)
            #/sbin/iptables --append INPUT --protocol tcp --sport 22 --dport 22 --jump ACCEPT
            #(crontab -l ; echo "@reboot /sbin/iptables --append INPUT --protocol tcp --sport 22 --dport 22 --jump ACCEPT >> /dev/null 2>&1")| crontab -
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            basicIPtable
    esac
}

# Apply a tuned performance profile, yes or no?
applyTuned(){
    # Question and description
    echo ""
    heading "Do you want to enable a tuned performance profile?"
    heading "This does not work on Debian 9, Ubuntu 16.04, or older."
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectTuned
    case $selectTuned in
        1 ) userSelectedYes
            if [ $osName == "rhel" ] || [ $osName == "centos" ] || [ $osName == "cloudlinux" ] || [ $osName == "fedora" ] || [ $osName == "rocky" ]; then
                yum -y install tuned
            elif [ $osName == "debian" ] || [ $osName == "ubuntu" ]; then
                apt -y install tuned
            fi
            tuned-adm profile latency-performance
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            selectTuned
    esac
}

# Enable Fail2Ban, yes or no?
enableFail2Ban(){
    # Question and description
    echo ""
    heading "Do you want to set up Fail2Ban?"
    heading "Fail2Ban is used to protect sshd against attacks."
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectFail2Ban
    case $selectFail2Ban in
        1 ) userSelectedYes
            if [ $osName == "rhel" ] || [ $osName == "centos" ] || [ $osName == "cloudlinux" ] || [ $osName == "fedora" ] || [ $osName == "rocky" ]; then
                yum -y install fail2ban
            elif [ $osName == "debian" ] || [ $osName == "ubuntu" ]; then
                apt -y install fail2ban
            fi
            systemctl enable fail2ban
            bash -c 'cat > /etc/fail2ban/jail.local' <<-'EOF'
[DEFAULT]
# Ban hosts for ten hours:
bantime = 36000
# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport
[sshd]
enabled = true
EOF
            service fail2ban restart
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            selectFail2Ban
    esac
}

# Disable SSH password authentication, yes or no?
disablePasswordAuth(){
    # Question and description
    echo ""
    heading "Do you want to disable ssh password authentication?"
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectPasswordAuth
    case $selectPasswordAuth in
        1 ) userSelectedYes
            sed -i 's/.*PasswordAuthentication no/PasswordAuthentication no/g' /etc/ssh/sshd_config
            systemctl restart ssh
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            disablePasswordAuth
    esac
}

# Enable JavaPipe Anti-DDoS kernel settings, yes or no?
javapipeKernel(){
    # Question and description
    echo ""
    heading "Do you want to apply JavaPipe's Anti-DDoS kernel settings?"
    heading "Read more over at: https://javapipe.com/blog/iptables-ddos-protection/"
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectJavaPipe
    case $selectJavaPipe in
        1 ) userSelectedYes
            bash -c 'cat > /etc/sysctl.conf' <<-'EOF'
kernel.printk = 4 4 1 7 
kernel.panic = 10 
kernel.sysrq = 0 
kernel.shmmax = 4294967296 
kernel.shmall = 4194304 
kernel.core_uses_pid = 1 
kernel.msgmnb = 65536 
kernel.msgmax = 65536 
vm.swappiness = 20 
vm.dirty_ratio = 80 
vm.dirty_background_ratio = 5 
fs.file-max = 2097152 
net.core.netdev_max_backlog = 262144 
net.core.rmem_default = 31457280 
net.core.rmem_max = 67108864 
net.core.wmem_default = 31457280 
net.core.wmem_max = 67108864 
net.core.somaxconn = 65535 
net.core.optmem_max = 25165824 
net.ipv4.neigh.default.gc_thresh1 = 4096 
net.ipv4.neigh.default.gc_thresh2 = 8192 
net.ipv4.neigh.default.gc_thresh3 = 16384 
net.ipv4.neigh.default.gc_interval = 5 
net.ipv4.neigh.default.gc_stale_time = 120 
net.netfilter.nf_conntrack_max = 10000000 
net.netfilter.nf_conntrack_tcp_loose = 0 
net.netfilter.nf_conntrack_tcp_timeout_established = 1800 
net.netfilter.nf_conntrack_tcp_timeout_close = 10 
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 10 
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 20 
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 20 
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 20 
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 20 
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10 
net.ipv4.tcp_slow_start_after_idle = 0 
net.ipv4.ip_local_port_range = 1024 65000 
net.ipv4.ip_no_pmtu_disc = 1 
net.ipv4.route.flush = 1 
net.ipv4.route.max_size = 8048576 
net.ipv4.icmp_echo_ignore_broadcasts = 1 
net.ipv4.icmp_ignore_bogus_error_responses = 1 
net.ipv4.tcp_congestion_control = htcp 
net.ipv4.tcp_mem = 65536 131072 262144 
net.ipv4.udp_mem = 65536 131072 262144 
net.ipv4.tcp_rmem = 4096 87380 33554432 
net.ipv4.udp_rmem_min = 16384 
net.ipv4.tcp_wmem = 4096 87380 33554432 
net.ipv4.udp_wmem_min = 16384 
net.ipv4.tcp_max_tw_buckets = 1440000 
net.ipv4.tcp_tw_reuse = 1 
net.ipv4.tcp_max_orphans = 400000 
net.ipv4.tcp_window_scaling = 1 
net.ipv4.tcp_rfc1337 = 1 
net.ipv4.tcp_syncookies = 1 
net.ipv4.tcp_synack_retries = 1 
net.ipv4.tcp_syn_retries = 2 
net.ipv4.tcp_max_syn_backlog = 16384 
net.ipv4.tcp_timestamps = 1 
net.ipv4.tcp_sack = 1 
net.ipv4.tcp_fack = 1 
net.ipv4.tcp_ecn = 2 
net.ipv4.tcp_fin_timeout = 10 
net.ipv4.tcp_keepalive_time = 600 
net.ipv4.tcp_keepalive_intvl = 60 
net.ipv4.tcp_keepalive_probes = 10 
net.ipv4.tcp_no_metrics_save = 1 
net.ipv4.ip_forward = 0 
net.ipv4.conf.all.accept_redirects = 0 
net.ipv4.conf.all.send_redirects = 0 
net.ipv4.conf.all.accept_source_route = 0 
net.ipv4.conf.all.rp_filter = 1
EOF
            sysctl -p
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            selectJavaPipe
    esac
}

# Enable the custom MOTD, yes or no?
motd(){
    # Question and description
    echo ""
    heading "Do you want to enable the custom MOTD?"
    yesQuestion
    skipQuestion
    echo ""

    # Apply changes
    read selectMOTD
    case $selectMOTD in
        1 ) userSelectedYes
            echo '

This server is in property of '"${username}"'.
Unauthorized access to this machine will be prosecuted by law.
Your IP address and coordinates has been logged for security purposes.

            ' | tee /etc/motd >/dev/null 2>&1
            ;;
        2 ) userSelectedNo
            ;;
        * ) userNoSelection
            selectMOTD
    esac
}

# Execute the steps
preCheck
updatePackages
blockICMP
basicIPtable
applyTuned
enableFail2Ban
disablePasswordAuth
javapipeKernel
motd

# Thank you
echo ""
heading "The setup is complete."
echo ""

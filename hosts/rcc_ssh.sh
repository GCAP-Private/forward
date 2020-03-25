#!/bin/bash
#
# RCC cluster at Chicago
# Prints an ssh configuration for the user, selecting a login node at random
# Sample usage: bash rcc_ssh.sh
echo
read -p "RCC username > "  USERNAME

echo "Host rcc
    User ${USERNAME}
    Hostname midway2-login1.rcc.uchicago.edu
    GSSAPIDelegateCredentials yes
    GSSAPIAuthentication yes
    ControlMaster auto
    ControlPersist yes
    ControlPath ~/.ssh/%l%r@%h:%p"

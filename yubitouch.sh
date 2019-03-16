#!/bin/bash

# Bash script for setting or clearing touch requirements for
# cryptographic operations the OpenPGP application on a YubiKey 4.
#
# Author: Alessio Di Mauro <alessio@yubico.com>

GCA=$(which gpg-connect-agent)
XXD=$(which xxd)
OD=$(which od)
DO=0
UIF=0

ascii_to_hex()
{
    if [ -n "$XXD" ]
    then
        $XXD -ps
    elif [ -n "$OD" ]
    then
        $OD -An -tx1
    fi
}

PE=$(which pinentry)
PE_PROMPT="SETPROMPT Admin PIN\nGETPIN\nBYE"

if [ -z "$GCA" ]
then
    echo "Can not find gpg-connect-agent. Aborting...";
    exit 1;
fi

if [ -z "$XXD" -a -z "$OD" ]
then
    echo "Can not find xxd(1) nor od(1). Aborting...";
    exit 1;
fi

if [ $# -lt 2 ] || [ $# -gt 3 ]
then
    echo "Wrong parameters"
    echo "usage: yubitouch {sig|aut|dec} {off|on|fix} [admin_pin]";
    exit 1;
fi

if [ "$1" == "sig" ]
then
    DO="D6"
elif [ "$1" == "dec" ]
then
    DO="D7"
elif [ "$1" == "aut" ]
then
    DO="D8"
else
    echo "Invalid value $1 (must be sig, aut, dec). Aborting..."
    exit 1
fi

if [ "$2" == "off" ]
then
    UIF="00";
elif [ "$2" == "on" ]
then
    UIF="01"
elif [ "$2" == "fix" ]
then
    UIF="02";
else
    echo "Invalid value $2 (must be off, on, fix). Aborting..."
    exit 1
fi

if [ $# -eq 3 ]
then
    PIN="$3"
elif [ -z "$PE" ]
then
    echo -e "Pinentry not present\nFalling back to regular stdin.\nBe careful!"
    echo "Enter your admin PIN: "
    read PIN
else
    PIN="$(echo -e $PE_PROMPT | $PE | sed -n '/^D .*/s/^D //p')"
fi

if [ -z "$PIN" ]
then
    echo "Empty PIN. Aborting..."
    exit 1
fi

PIN_LEN=${#PIN}

PIN=$(echo -n "$PIN" | ascii_to_hex | tr -d '\n')

PIN_LEN=$(printf %02x $PIN_LEN)

$GCA --hex "scd reset" /bye > /dev/null

VERIFY=$($GCA --hex "scd apdu 00 20 00 83 $PIN_LEN $PIN" /bye)
if ! echo $VERIFY | grep -q "90 00"
then
    echo "Verification failed, wrong pin?"
    exit 1
fi

PUT=$($GCA --hex "scd apdu 00 da 00 $DO 02 $UIF 20" /bye)
if ! echo $PUT | grep -q "90 00"
then
    echo "Unable to change mode. Set to fix?"
    exit 1
fi

echo "All done!"
exit 0

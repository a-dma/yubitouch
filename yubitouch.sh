#!/bin/sh

# Shell script for reading, setting or clearing touch requirements for
# cryptographic operations using the OpenPGP application on a
# YubiKey 4 or YubiKey 5.
#
# Author: Alessio Di Mauro <alessio@yubico.com>

GCA=$(command -v gpg-connect-agent)
XXD=$(command -v xxd)
OD=$(command -v od)
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

PE=$(command -v pinentry)
PE_PROMPT='SETPROMPT Admin PIN\nGETPIN\nBYE\n'

if [ -z "$GCA" ]
then
    echo "Can not find gpg-connect-agent. Aborting..." >&2
    exit 1;
fi

if [ -z "$XXD" ] && [ -z "$OD" ]
then
    echo "Can not find xxd(1) nor od(1). Aborting..." >&2
    exit 1;
fi

if [ $# -lt 2 ] || [ $# -gt 3 ]
then
    echo "Wrong parameters" >&2
    echo "usage: yubitouch {sig|aut|dec|att} {get|off|on|fix|cacheon|cachefix} [admin_pin]" >&2
    exit 1;
fi

if [ "$1" = "sig" ]
then
    DO="D6"
elif [ "$1" = "dec" ]
then
    DO="D7"
elif [ "$1" = "aut" ]
then
    DO="D8"
elif [ "$1" = "att" ]
then
    DO="D9"
else
    echo "Invalid value $1 (must be sig, aut, dec, att). Aborting..." >&2
    exit 1
fi

if [ "$2" = "get" ]
then
    $GCA --hex "scd reset" /bye > /dev/null

    GET=$($GCA --hex "scd apdu 00 ca 00 $DO 00" /bye)
    if ! echo "$GET" | grep -q "90 00"
    then
        echo "Get data failed, unsupported device?" >&2
        exit 1
    fi

    STATUS=$(echo "$GET" | grep -oE "[0-9]{2} 20 90 00" | cut -c 1-2)

    if [ "$STATUS" = "00" ]
    then
        UIF="off"
    elif [ "$STATUS" = "01" ]
    then
        UIF="on"
    elif [ "$STATUS" = "02" ]
    then
        UIF="fix"
    elif [ "$STATUS" = "03" ]
    then
        UIF="cacheon"
    elif [ "$STATUS" = "04" ]
    then
        UIF="cachefix"
    else
        echo "Unknown touch setting status ($STATUS)" >&2
        exit 1
    fi

    echo "Current $1 touch setting: $UIF" >&2
    exit 0
elif [ "$2" = "off" ]
then
    UIF="00";
elif [ "$2" = "on" ]
then
    UIF="01"
elif [ "$2" = "fix" ]
then
    UIF="02";
elif [ "$2" = "cacheon" ]
then
    UIF="03";
elif [ "$2" = "cachefix" ]
then
    UIF="04";
else
    echo "Invalid value $2 (must be get, off, on, fix, cacheon, cachefix). Aborting..." >&2
    exit 1
fi

if [ $# -eq 3 ]
then
    PIN="$3"
elif [ -z "$PE" ]
then
    echo "Pinentry not present" >&2
    echo "Falling back to regular stdin." >&2
    echo "Be careful!" >&2
    echo "Enter your admin PIN: "
    read -r PIN
else
    CURRENT_TTY=$(tty)
    # shellcheck disable=SC2059
    PIN=$(printf "$PE_PROMPT" | $PE --ttyname "$CURRENT_TTY" | sed -n '/^D .*/s/^D //p')
fi

if [ -z "$PIN" ]
then
    echo "Empty PIN. Aborting..." >&2
    exit 1
fi

PIN_LEN=${#PIN}

# shellcheck disable=SC2059
PIN=$(printf "$PIN" | ascii_to_hex | tr -d '\n')

PIN_LEN=$(printf %02x "$PIN_LEN")

$GCA --hex "scd reset" /bye > /dev/null

VERIFY=$($GCA --hex "scd apdu 00 20 00 83 $PIN_LEN $PIN" /bye)
if ! echo "$VERIFY" | grep -q "90 00"
then
    echo "Verification failed, wrong pin?" >&2
    exit 1
fi

PUT=$($GCA --hex "scd apdu 00 da 00 $DO 02 $UIF 20" /bye)
if ! echo "$PUT" | grep -q "90 00"
then
    echo "Unable to change mode. Set to fix?" >&2
    exit 1
fi

echo "All done!"
exit 0

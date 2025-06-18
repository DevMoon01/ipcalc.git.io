#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <indirizzo IP> oppure <indirizzo IP/mask>"
    exit 1
fi

ip="$1"

# Se l'utente non ha specificato il prefisso CIDR, impostiamo /24 di default
if [[ "$ip" != */* ]]; then
    ip="$ip/24"
fi

IFS='/'
read -ra ADDR <<< "$ip"
address="${ADDR[0]}"
mask="${ADDR[1]}"

calc_netmask() {
    bits=$1
    mask=""
    for i in {1..4}; do
        if [ "$bits" -ge 8 ]; then
            mask+="255"
            bits=$((bits - 8))
        else
            mask+=$((256 - 2**(8 - bits)))
            bits=0
        fi
        if [ "$i" -lt 4 ]; then
            mask+="."
        fi
    done
    echo "$mask"
}

calc_wildcard() {
    netmask=$(calc_netmask "$1")
    IFS='.'
    read -ra octets <<< "$netmask"
    wildcard=""
    for octet in "${octets[@]}"; do
        wildcard+=$((255 - octet))"."
    done
    echo "${wildcard::-1}"
}

calc_network() {
    IFS='.'
    read -ra ip_octets <<< "$1"
    read -ra mask_octets <<< "$(calc_netmask "$2")"
    network=""
    for i in {0..3}; do
        network+=$((ip_octets[i] & mask_octets[i]))"."
    done
    echo "${network::-1}"
}

calc_broadcast() {
    IFS='.'
    read -ra ip_octets <<< "$1"
    read -ra mask_octets <<< "$(calc_netmask "$2")"
    broadcast=""
    for i in {0..3}; do
        broadcast+=$(((ip_octets[i] & mask_octets[i]) | (255 - mask_octets[i])))"."
    done
    echo "${broadcast::-1}"
}

calc_host_range() {
    network=$(calc_network "$1" "$2")
    broadcast=$(calc_broadcast "$1" "$2")

    IFS='.'
    read -ra net_octets <<< "$network"
    read -ra bc_octets <<< "$broadcast"

    hostmin="${net_octets[0]}.${net_octets[1]}.${net_octets[2]}.$((net_octets[3] + 1))"
    hostmax="${bc_octets[0]}.${bc_octets[1]}.${bc_octets[2]}.$((bc_octets[3] - 1))"

    echo "$hostmin;$hostmax"
}

calc_network_class() {
    IFS='.'
    read -ra octets <<< "$1"
    first_octet=${octets[0]}

    if [ "$first_octet" -ge 1 ] && [ "$first_octet" -le 126 ]; then
        echo "Classe A"
    elif [ "$first_octet" -ge 128 ] && [ "$first_octet" -le 191 ]; then
        echo "Classe B"
    elif [ "$first_octet" -ge 192 ] && [ "$first_octet" -le 223 ]; then
        echo "Classe C"
    elif [ "$first_octet" -ge 224 ] && [ "$first_octet" -le 239 ]; then
        echo "Classe D (Multicast)"
    elif [ "$first_octet" -ge 240 ] && [ "$first_octet" -le 255 ]; then
        echo "Classe E (Riservata)"
    else
        echo "Sconosciuta"
    fi
}

netmask=$(calc_netmask "$mask")
wildcard=$(calc_wildcard "$mask")
network=$(calc_network "$address" "$mask")
broadcast=$(calc_broadcast "$address" "$mask")
hosts=$((2**(32-mask) - 2))
host_range=$(calc_host_range "$address" "$mask")
network_class=$(calc_network_class "$address")

IFS=';'
read -ra hosts_data <<< "$host_range"

echo "Address: $address"
echo "NetMask: $netmask"
echo "Wildcard: $wildcard"
echo "Network: $network"
echo "Hostmin: ${hosts_data[0]}"
echo "Hostmax: ${hosts_data[1]}"
echo "Broadcast: $broadcast"
echo "Hosts/Net: $hosts"
echo "Network Class: $network_class"

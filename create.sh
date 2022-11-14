#!/bin/bash
set -euo pipefail

mirage_stuff () {
    mirage config -t "$TARGET" --dhcp "$DHCP" --token "$COFFEE_TOKEN" --ssh-key "$SSH" --channel "$CHANNEL" --remote "$REMOTE" --num-iter "$NUM_ITER" --test "$IS_TEST" --curl-user-id "$CURL_USER_ID" --bot-id "$COFFEE_ID"
    make depend
    sed -i 's/main)/main) (preprocess (pps ppx_deriving_yojson))/g' dune.build # currently, the mirage config doesn't add ppxs to dune.build
    mirage build
}

unikernel () {
  eval "$(opam env)"
  source ./config_env.sh
  case $1 in
    test)
      export CHANNEL=$TEST_CHANNEL
      export REMOTE=$TEST_REMOTE
      export NUM_ITER=1000
      export IS_TEST="true"
      ;;
    coffee)
      export CHANNEL=$COFFEE_CHANNEL
      export REMOTE=$COFFEE_REMOTE
      export NUM_ITER=100000000
      export IS_TEST="false"
      ;;
    *)
      echo "Do you want a real coffee or a test coffee?"
      exit 1
  esac
  case $2 in
    unix)
      export TARGET="unix"
      export DHCP="false"
       mirage_stuff
      ;;
    hvt)
      export TARGET="hvt"
      export DHCP="false"
      mirage_stuff
      ;;
    virtio)
      export TARGET="virtio"
      export DHCP="true"
      mirage_stuff
      "$VIRTIO_MKIMAGE" -f tar -- dist/disk.raw.tar.gz dist/coffee-chats.virtio
      ;;
    *)
      echo "What's the target for your coffee? Mug or glass?"
  esac
}

network () {
  sudo ip tuntap add tap0 mode tap # add a new network interface called tap0
  sudo ip addr add 10.0.0.1/24 dev tap0 # assign IP 10.0.0.1/24 to network interface tap0
  sudo ip link set tap0 up # enable network interface tap0
  sudo iptables -I FORWARD -i tap0 -o wlp0s20f3 -j ACCEPT # add rule to forward chain to forward all packets from tap0 to wifi interface
  sudo iptables -I FORWARD -i wlp0s20f3 -o tap0 -m state --state ESTABLISHED,RELATED -j ACCEPT # add rule to forward chain to forward all packets from wifi interface to tap0
  sudo iptables -t nat -A POSTROUTING -o wlp0s20f3 -j MASQUERADE # tweak the target IP of response package from unikernel IP to hostsystem IP: "masquerading"
}

case $1 in
  unikernel)
    unikernel "$2" "$3";;
  network)
    network;;
  spawn_hvt)
    eval "$(opam env)"
    solo5-hvt --net:service=tap0 dist/coffee-chats.hvt --ipv4=10.0.0.2/24 --ipv4-gateway=10.0.0.1;;
  *)
    echo "try $./create.sh unikernel test unix"
    exit 1
esac

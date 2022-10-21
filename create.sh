#!/bin/bash
set -euo pipefail

mirage_stuff () {
    mirage config -t "$TARGET" --dhcp "$DHCP" --token "$TOKEN" --ssh-key "$SSH" --channel "$CHANNEL" --remote "$REMOTE" --num-iter "$NUM_ITER" --test "$IS_TEST"
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
      ;;
    hvt)
      export TARGET="hvt"
      export DHCP="false"
      ;;
    virtio)
      export TARGET="virtio"
      export DHCP="true"
      ;;
    *)
      echo "What's the target for your coffee? Mug or glass?"
  esac
  mirage_stuff
}

network () {
  sudo ip tuntap add tap0 mode tap # add a new network interface called tap0
  sudo ip addr add 10.0.0.1/24 dev tap0 # assign IP 10.0.0.1/24 to network interface tap0
  sudo ip link set tap0 up # enable network interface tap0
  sudo iptables -I FORWARD -j ACCEPT -i tap0 # add rule to forward chain to forward all packets going through tap0
  sudo iptables -t nat -A POSTROUTING -o wlp0s20f3 -j MASQUERADE # tweak the target IP of response package from unikernel IP to hostsystem IP: "masquerading"
}

case $1 in
  unikernel)
    unikernel "$2" "$3";;
  network)
    network;;
  spawn_hvt)
    solo5-hvt --net:service=tap0 dist/coffee-chats.hvt --ipv4=10.0.0.2/24 --ipv4-gateway=10.0.0.1;;
  *)
    echo "try $./create.sh unikernel test unix"
    exit 1
esac

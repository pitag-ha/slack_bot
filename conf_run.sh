#!/bin/bash
set -e

eval $(opam env)
source ./config_env.sh
mirage config -t hvt --token $TOKEN --channel $TEST_CHANNEL --remote $TEST_REMOTE --ssh-key $SSH
make depend
sed -i 's/config manifest))/config manifest)) (preprocess (pps ppx_deriving_yojson))/g' dune.build
mirage build
solo5-hvt --net:service=tap0 dist/coffee-chats.hvt --ipv4=10.0.0.2/24 --ipv4-gateway=10.0.0.1

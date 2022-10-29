#!/bin/bash
source .env;
forge script script/DeployGoerli.s.sol:DeployLP --rpc-url $GOERLI_RPC --broadcast --verify -vvv


#!/bin/bash
source .env;
forge script script/DeployProd.s.sol:DeployLP --rpc-url $PROD_RPC --broadcast --verify -vvv
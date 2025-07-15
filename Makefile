-include .env

.PHONY: deploy

deploy :; forge script script/DeployDTsla.s.sol --private-key ${PRIVATE_KEY} --rpc-url ${RPC_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify 

deploy_USDC :; forge script script/DeployTUSDC.s.sol \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  --broadcast \
  --verify \
  -vvvv
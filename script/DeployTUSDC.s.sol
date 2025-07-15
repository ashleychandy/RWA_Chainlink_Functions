// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/Test_USDC.sol";

contract DeployTestUsdc is Script {
    function run() external {
        vm.startBroadcast();

        Test_USDC token = new Test_USDC();

        vm.stopBroadcast();
    }
}

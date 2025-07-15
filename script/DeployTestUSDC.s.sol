// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "src/Test_USDCUpgradable.sol";

contract DeployTestUsdc is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // Deploy implementation logic contract
        Test_USDC_Upgradable implementation = new Test_USDC_Upgradable();

        // Encode the call to initialize()
        bytes memory data = abi.encodeCall(Test_USDC_Upgradable.initialize, ());

        // Deploy proxy pointing to logic contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        // Interact with proxy as Test_USDC_Upgradable
        Test_USDC_Upgradable testUsdc = Test_USDC_Upgradable(address(proxy));

        console2.log("Proxy deployed at:", address(testUsdc));

        // Mint tokens to deployer
        testUsdc.mint(deployer, 10_000 * 1e18);

        console2.log("Minted 10,000 TUSDC to:", deployer);

        vm.stopBroadcast();
    }
}

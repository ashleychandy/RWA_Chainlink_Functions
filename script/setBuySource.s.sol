// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/dTSLA.sol"; // Update with correct path

contract CallSetBuySource is Script {
    string constant alpacaMintSource = "./functions/sources/buySellTsla.js";

    function run() external {
        vm.startBroadcast();
        string memory mintSource = vm.readFile(alpacaMintSource);

        // Replace with your deployed contract address
        address contractAddress = 0x0932e44AfA92137355c156513588d0712c320CA2;

        // Cast the address to your contract type
        dTSLA contractInstance = dTSLA(contractAddress);

        // Call the function
        contractInstance.setBuySource(mintSource); // Replace with your desired input

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Test_USDC_Upgradable is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    mapping(address => bool) private s_userToMinted;

    function initialize() external initializer {
        __ERC20_init("Test_USDC", "TUSDC");
        __Ownable_init(msg.sender);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function airdrop() external {
        if (!s_userToMinted[msg.sender]) {
            s_userToMinted[msg.sender] = true;
            _mint(msg.sender, 2000 * 1e18);
        } else {
            revert("Already minted");
        }
    }
}

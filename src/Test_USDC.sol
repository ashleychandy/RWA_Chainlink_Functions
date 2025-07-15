// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Test_USDC is ERC20, Ownable {
    mapping(address => bool) private s_userToMinted;

    constructor() ERC20("Test_USDC", "TUSDC") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function airdrop() external {
        if (!s_userToMinted[msg.sender]) {
            s_userToMinted[msg.sender] = true;
            _mint(msg.sender, 5000 * 1e18);
        } else {
            revert("Already minted");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedMintDSC is ERC20, Ownable {
    constructor() ERC20("MockFailedMintDSC", "MFDSC") Ownable(msg.sender) {}

    // Engine (owner) can call mint, but it "fails" by returning false
    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0) || amount == 0) {
            return false; // or revert if you want to test revert path
        }
        _mint(to, amount);
        return false; // always fail to trigger MintFailed in engine
    }

    // Optional: realistic burn, restricted to owner (engine)
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
}
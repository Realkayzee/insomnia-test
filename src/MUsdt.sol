// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MUsdt is ERC20 {
    constructor(address _deployer, uint256 _totalSupply) ERC20("MUSDT", "MUSDT") {
        _mint(_deployer, _totalSupply);
    }
}

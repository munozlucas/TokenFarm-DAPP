//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DappToken is ERC20 {
    
    constructor() public ERC20("Dapp Token", "DAPP") {
        _mint(msg.sender, 1000000 * 10**8);
    }
}

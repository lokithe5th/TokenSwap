pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
    }

    function faucet(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
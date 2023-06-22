// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenShop is ERC721 {
    address public target;
    address public pendingTarget;
    uint256 public targetFunds;

    uint256 public supply;

    uint256 public constant ACCESS_COST = 0.005 ether;
    uint256 public constant USE_COST = 0.001 ether;
    address public constant SENTINEL = address(1);

    error UnsufficientValue();
    error Exists();
    error NoFunds();
    error NoMarket();
    error NoTransfer();
    error Unauthorized();

    struct Invoice {
        address seller;
        address token;
        uint256 amountOfTokens;
        uint256 cost;
    }

    mapping(address => uint256) public accounts;
    mapping(address => bool) public markets;
    mapping(uint256 => Invoice) public invoices;

    constructor(address _target) ERC721("TokenShop: Invoice", "TSI") {
        target = _target;
        markets[SENTINEL] = SENTINEL;
    }

    function buyAccess() external payable {
        if (!msg.value == 0.005 ether) {
            revert InsufficientValue();
        }

        accounts[msg.sender] = msg.value;
    }

    function createMarket(address targetToken) external {
        if (accounts[msg.sender] < 0.001 ether) {
            revert NoFunds();
        }

        if (markets[targetToken]) revert Exists();

        accounts[msg.sender] -= 0.001 ether;
        targetFunds += 0.001 ether;
        markets[targetToken] = true;
    }

    function sellTokens(address targetToken, uint256 amount) external {
        if (!markets[targetToken]) revert NoMarket();
        if (accounts[msg.sender] < 0.001 ether) revert NoFunds();

        accounts[msg.sender] -= 0.001 ether;
        invoices[supply] = new Invoice(msg.sender, targetToken, amount, USE_COST);
        _mint(msg.sender, supply);
        supply++;

        IERC20 token = IERC20(targetToken);
        uint256 startingBalance = token.balanceOf(address(this));

        token.transferFrom(msg.sender, address(this), amount);

        if (token.balanceOf(address(this)) != startingBalance + amount) revert NoTransfer();
    }

    function changeTarget(address newTarget) external {
        if (msg.sender != target) revert Unuathorized();
        pendingTarget = newTarget;
    }

    function claimTarget() external {
        if (msg.sender != pendingTarget) revert Unauthorized();
        target = pendingTarget;
        delete pendingTarget;
    }
}
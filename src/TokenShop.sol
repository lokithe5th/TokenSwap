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

    error InsufficientValue();
    error Exists();
    error NoFunds();
    error NoMarket();
    error NotAllowed();
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

    /****************************************************************
     *                  MEMBERSHIP FUNCTIONS
     ****************************************************************/

    /// @notice Buy access to the TokenShop
    /// @dev The message value must be at least 0.005 ether
    function buyAccess() external payable {
        if (msg.value < 0.005 ether) revert InsufficientValue();

        accounts[msg.sender] = msg.value;
    }

    /****************************************************************
     *                  MARKET MAKING
     ****************************************************************/

    /// @notice Permissionlessly create a market pool for `targetToken`
    /// @param targetToken Address of the token that is being added
    function createMarket(address targetToken) external {
        if (accounts[msg.sender] < 0.001 ether) {
            revert NoFunds();
        }

        if (markets[targetToken]) revert Exists();

        accounts[msg.sender] -= 0.001 ether;
        targetFunds += 0.001 ether;
        markets[targetToken] = true;
    }

    /// @notice Sell tokens to the TokenShop for a fixed price
    /// @dev The seller must have approved the TokenShop for `amount`
    /// @param targetToken Address of the token the seller wishes to make a market for
    /// @param amount The amount of the specified token the seller wishes to sell
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

    /****************************************************************
     *                  TO DO: SVG INVOICE VIEWERS
     ***************************************************************/

    /****************************************************************
     *                  MANAGEMENT FUNCTIONS
     ****************************************************************/

    /// @notice Allows a beneficiary organization to transfer out tokens
    /// @dev Beneficiaries can be degen too! But caller must audit ERC20 code. 
    /// @note ASSUME ALL TOKENS ARE HOSTILE UNLESS CONFIRMED OTHERWISE
    function transferTokens(address targetToken, address to, uint256 amount) external {
        if (msg.sender != target) revert Unauthorized();

        IERC20(targetToken).transfer(to, amount);
    }

    /// @notice Allows the `target` to withdraw accrued feess
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
    function withdrawFees(address to) external {
        if (msg.sender != target) revert Unauthorized();
        uint256 funds = targetFunds;
        delete targetFunds;

        (bool success, ) = to.call{value: funds}("");
        if (!success) revert NoTransfer();        
    }

    /****************************************************************
     *                  BENEFICIARY SETTERS
     ****************************************************************/

    /// @notice Nominates a new beneficiary
    /// @param newTarget The address that can claim accumalated fees
    function changeTarget(address newTarget) external {
        if (msg.sender != target) revert Unuathorized();
        pendingTarget = newTarget;
    }

    /// @notice Allows a nominated beneficiary to accept nomination
    function claimTarget() external {
        if (msg.sender != pendingTarget) revert Unauthorized();
        target = pendingTarget;
        delete pendingTarget;
    }

    /// @notice The TokenShop does not allow direct ETH transfers
    receive() external {
        revert NotAllowed();
    }
}
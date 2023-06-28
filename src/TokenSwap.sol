// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

/// @title TokenSwap
/// @author lourens
/// @notice Permissionless fixed-price market maker for ERC20 tokens that crashed in value

contract TokenSwap is ERC721 {
    using Strings for uint256;
    /// Target is the address to which market creation fees go
    address public target;
    /// Address nominated to take over collection of market creation fees
    address public pendingTarget;
    /// Amount of ether accrued to the `target`
    uint256 public targetFunds;

    /// The amount of markets created
    uint256 public supply;

    string[] private template = [
        "TokenSwap Invoice",
        "INV-",
        "Seller: ",
        "Token: ",
        "Amount: ",
        "Paid: ",
        "Block: "
    ];

    string[10] internal svgParts = [
        '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 400"><style>.base { fill: white; font-family: monospace; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">',
        '</text><text x="10" y="40" class="base">',
        '</text><text x="10" y="60" class="base">',
        '</text><text x="10" y="80" class="base">',
        '</text><text x="10" y="100" class="base">',
        '</text><text x="10" y="120" class="base">',
        '</text><text x="10" y="140" class="base">',
//        '</text><text x="10" y="160" class="base">',
//        '</text><text x="10" y="160" class="base">',
        '</text></svg>'
    ];

    /****************************************************************
     *                  CONSTANTS                                   *
     ****************************************************************/

    /// The cost to gain access to TokenSwap
    uint256 public constant ACCESS_COST = 0.005 ether;
    /// The cost to call `createMarket` and `sellTokens`
    /// @dev this `USE_COST` is deducted from the callers internal `accounts[caller]`
    uint256 public constant USE_COST = 0.001 ether;

    /****************************************************************
     *                  ERRORS                                      *
     ****************************************************************/
    /// `msg.value` is too low
    error InsufficientValue();
    /// The market already exists
    error Exists();
    /// Invoice has not been issued yet
    error Invalid();
    /// The internal account balance is too low for requested action
    error NoFunds();
    /// No market has been created for the selected token
    error NoMarket();
    /// Please donate direct deposits to buidlguidl.eth
    error NotAllowed();
    /// The requested token transfer was unsuccessful
    error NoTransfer();
    /// Exactly what is says :-\
    error Unauthorized();

    /// Holds data from which invoice SVG can be built
    /// We exclude `cost` here because the price offered is always `USE_COST`
    struct Invoice {
        address seller; /// the account selling the tokens
        address token; /// the token that was sold
        uint256 amountOfTokens; /// the amount of tokens sold
        uint256 blocknumber; /// Assists with tracing/verifying
    }

    /// Accounts to deposits
    mapping(address => uint256) public accounts;
    /// Is a market available for trading?
    mapping(address => bool) public markets;
    /// TokenId to Invoice
    mapping(uint256 => Invoice) public invoices;

    constructor(address _target) ERC721("TokenSwap: Invoice", "TSI") {
        target = _target;
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
     *                  WIP: SVG INVOICE VIEWERS                  *
     ****************************************************************/
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

      string memory json = Base64.encode(
        bytes(string.concat(
          '{"name": "Invoice #', uint2str(id), ' "description": "TokenSwap Invoice", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(generateSVGofTokenById(id))), '"}'))));

        json = string.concat('data:application/json;base64,', json);
      return json;
    }

    /// @notice Public facing render function
    /// @dev    Visibility is `public` to enable it being called by other contracts for composition.
    /// @param  id Target for rendering
    /// @return string SVG image represented as a string
    function renderTokenById(uint256 id) public view returns (string memory) {
        return generateSVGofTokenById(id);
    }

    /// @notice Generates an SVG image which can be read offline.
    /// @param id Target invoice number
    /// @return SVG in string form
    /**
     * TokenSwap Invoice
     * INV-{id}
     * Seller: {invoices[id].seller}
     * Token: {invoices[id].token}
     * Amount: {invoices[id].amountOfTokens}
     * Paid: 0.001 ether
     * Block: {invoices[id].blocknumber}
     */
    function generateSVGofTokenById(uint256 id) public view returns (string memory) {
        if (invoices[id].seller == address(0)) revert Invalid();
        Invoice storage targetInvoice = invoices[id];

        string memory svg = string.concat(svgParts[0], template[0], svgParts[1], template[1], toString(id), svgParts[2], template[2], toHexString(targetInvoice.seller), svgParts[3], template[3], toHexString(targetInvoice.token), svgParts[4]);
        svg = string.concat(svg, template[4], toString(targetInvoice.amountOfTokens), svgParts[5], template[5], "0.001 ether", svgParts[6], template[6], toString(targetInvoice.blockNumber) svgParts[9]);
        return svg;
    }

    /****************************************************************
     *                  MANAGEMENT FUNCTIONS                        *
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
     *                  BENEFICIARY SETTERS                         *
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
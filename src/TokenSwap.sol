// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";

/// @title TokenSwap
/// @author lourens
/// @notice Permissionless fixed-price market maker for ERC20 tokens that crashed in value

contract TokenSwap is ERC721 {
    using Strings for uint256;
    using Strings for address;
    /// Target is the address to which market creation fees go
    address public target;
    /// Address nominated to take over collection of market creation fees
    address public pendingTarget;
    /// Amount of ether accrued to the `target`
    uint256 public targetFunds;

    /// The amount of markets created
    uint256 public supply;

/*
    string[] private template = [
        "TokenSwap Invoice",
        "INV-",
        "Seller: ",
        "Token: ",
        "Amount: ",
        "Paid: ",
        "Block: "
    ];
*/
    bytes17 internal headingLbl = 0x546f6b656e5377617020496e766f696365; // TokenSwap Invoice
    bytes4 internal invoiceNumberLbl = 0x494e562d;
    bytes12 internal sellerLbl = 0x494e562d53656c6c65723a20;
    bytes7 internal tokenLbl = 0x546f6b656e3a20;
    bytes8 internal amountLbl = 0x416d6f756e743a20;
    bytes6 internal paidLbl = 0x506169643a20;
    bytes7 internal blockLbl = 0x426c6f636b3a20;

    bytes32 internal svgStart0 = 0x3c73766720786d6c6e733d22687474703a2f2f7777772e77332e6f72672f3230;
    bytes32 internal svgStart1 = 0x30302f73766722207072657365727665417370656374526174696f3d22784d69;
    bytes32 internal svgStart2 = 0x6e594d696e206d656574222076696577426f783d223020302033353020343030;
    bytes32 internal svgStart3 = 0x223e3c7374796c653e2e62617365207b666f6e742d73697a653a313470783b7d;
    bytes32 internal svgStart4 = 0x3c2f7374796c653e3c726563742077696474683d223130302522206865696768;
    bytes32 internal svgStart5 = 0x743d2231303025222066696c6c3d22626c61636b222f3e3c7465787420783d22;
    bytes32 internal svgStart6 = 0x31302220793d2232302220636c6173733d2262617365223e0000000000000000;
    


    /// Equivalent to <svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 400"><style>.base {font-size:14px;}</style><rect width="100%" height="100%" fill="black"/><text x="10" y="20" class="base">
/*    bytes32[7] internal svgPart0 =  [
                                    0x3c73766720786d6c6e733d22687474703a2f2f7777772e77332e6f72672f3230,
                                    0x30302f73766722207072657365727665417370656374526174696f3d22784d69,
                                    0x6e594d696e206d656574222076696577426f783d223020302033353020343030,
                                    0x223e3c7374796c653e2e62617365207b666f6e742d73697a653a313470783b7d,
                                    0x3c2f7374796c653e3c726563742077696474683d223130302522206865696768,
                                    0x743d2231303025222066696c6c3d22626c61636b222f3e3c7465787420783d22,
                                    0x31302220793d2232302220636c6173733d2262617365223e0000000000000000
                                ];
*/
    //bytes1[] internal svgPart1 = 0x3c2f746578743e3c7465787420783d2231302220793d2234302220636c6173733d2262617365223e;
    //bytes1[] internal svgPart2 = 0x3c2f746578743e3c7465787420783d2231302220793d2236302220636c6173733d2262617365223e;
    //bytes1[] internal svgPart3 = 0x3c2f746578743e3c7465787420783d2231302220793d223134302220636c6173733d2262617365223e;

    /// Equal to "</text><text x="10" y="
    bytes24 internal svgLinePart1 = 0x3c2f746578743e3c7465787420783d2231302220793d2230;
    /// Equal to " class="base">
    bytes16 internal svgLinePart2 = 0x302220636c6173733d2262617365223e;
    bytes13 internal svgEnd = 0x3c2f746578743e3c2f7376673e;

/*
    string[8] internal svgParts = [
        '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 400"><style>.base {font-size:14px;}</style><rect width="100%" height="100%" fill="black"/><text x="10" y="20" class="base">',
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
*/
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
        supply++;

        Invoice storage invoice = invoices[supply];
        invoice.seller = msg.sender;
        invoice.token = targetToken;
        invoice.amountOfTokens = amount;
        invoice.blocknumber = block.number;

        _mint(msg.sender, supply);

        IERC20 token = IERC20(targetToken);
        uint256 startingBalance = token.balanceOf(address(this));

        token.transferFrom(msg.sender, address(this), amount);

        if (token.balanceOf(address(this)) != startingBalance + amount) revert NoTransfer();
    }

    /****************************************************************
     *                  WIP: SVG INVOICE VIEWERS                  *
     ****************************************************************/
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
      string memory json = Base64.encode(
        bytes(string.concat(
          '{"name": "Invoice #', tokenId.toString(), ' "description": "TokenSwap Invoice", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(generateSVGofTokenById(tokenId))), '"}')));

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

        string memory svg = string(abi.encodePacked(createSVGStart(), invoiceNumberLbl, id.toString(), createSVGLine(60), sellerLbl, invoices[id].seller.toHexString()));
        svg = string(abi.encodePacked(svg, createSVGLine(80), tokenLbl, invoices[id].token.toHexString(), createSVGLine(100)));
        return string(abi.encodePacked(svg, amountLbl, invoices[id].amountOfTokens.toString(), createSVGMiddle(), invoices[id].blocknumber.toString(), svgEnd));
    }

    function createSVGLine(uint256 y) internal view returns (string memory) {
        return string(abi.encodePacked(svgLinePart1, y.toString(), svgLinePart2));
    }

    function createSVGStart() internal view returns (string memory) {
        return string(abi.encodePacked(svgStart0, svgStart1, svgStart2, svgStart3, svgStart4, svgStart5, svgStart6, headingLbl, createSVGLine(40)));
    }

    function createSVGMiddle() internal view returns (string memory) {
        return string(abi.encodePacked(createSVGLine(120), paidLbl, "0.001 ether", createSVGLine(140), blockLbl));
    }

    /****************************************************************
     *                  MANAGEMENT FUNCTIONS                        *
     ****************************************************************/

    /// @notice Allows a beneficiary organization to transfer out tokens
    /// @dev Beneficiaries can be degen too! But caller must audit ERC20 code. 
    /// ASSUME ALL TOKENS ARE HOSTILE UNLESS CONFIRMED OTHERWISE
    function transferTokens(address targetToken, address to, uint256 amount) external {
        if (msg.sender != target) revert Unauthorized();

        IERC20(targetToken).transfer(to, amount);
    }

    /// @notice Allows the `target` to withdraw accrued feess
    /// @param to address to which to transfer `targetFunds`
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
        if (msg.sender != target) revert Unauthorized();
        pendingTarget = newTarget;
    }

    /// @notice Allows a nominated beneficiary to accept nomination
    function claimTarget() external {
        if (msg.sender != pendingTarget) revert Unauthorized();
        target = pendingTarget;
        delete pendingTarget;
    }

    /// @notice The TokenShop does not allow direct ETH transfers
    receive() payable external {
        revert NotAllowed();
    }
}
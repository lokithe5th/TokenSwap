// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";

/// @title TokenSwap
/// @author @lourens
/// @notice Permissionless fixed-price market maker for ERC20 tokens that crashed in value

contract TokenSwap is ERC721 {
    using Strings for uint256;
    using Strings for address;
    /// Target is the address to which market creation fees go
    address public target;
    /// Locked or not
    uint96 private _locked;

    /// Address nominated to take over collection of market creation fees
    address public pendingTarget;

    /// Amount of ether accrued to the `target`
    uint256 public targetFunds;

    /// The amount of markets created
    uint256 public supply;

    /****************************************************************
     *                  CONSTANTS                                   *
     ****************************************************************/

    /// The cost to gain access to TokenSwap
    uint256 public constant ACCESS_COST = 0.005 ether;
    /// The cost to call `createMarket` and `sellTokens`
    /// @dev this `USE_COST` is deducted from the callers internal `accounts[caller]`
    uint256 public constant USE_COST = 0.001 ether;

    bytes17 internal constant headingLbl = 0x546f6b656e5377617020496e766f696365; // "TokenSwap Invoice"
    bytes4 internal constant invoiceNumberLbl = 0x494e562d; // "INV-"
    bytes12 internal constant sellerLbl = 0x494e562d53656c6c65723a20; // "Seller: "
    bytes7 internal constant tokenLbl = 0x546f6b656e3a20; // "Token: "
    bytes8 internal constant amountLbl = 0x416d6f756e743a20; // "Amount: "
    bytes6 internal constant paidLbl = 0x506169643a20; // "Cost: "
    bytes7 internal constant blockLbl = 0x426c6f636b3a20; // "Block: "
    bytes11 internal constant priceLbl = 0x302e303031206574686572; // "0.001 ether"

    // Equivalent to '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 400"><style>.base {font-size:14px;}</style><rect width="100%" height="100%" fill="black"/><text x="10" y="20" class="base">',
    bytes32 internal constant svgStart0 = 0x3c73766720786d6c6e733d22687474703a2f2f7777772e77332e6f72672f3230;
    bytes32 internal constant svgStart1 = 0x30302f73766722207072657365727665417370656374526174696f3d22784d69;
    bytes32 internal constant svgStart2 = 0x6e594d696e206d656574222076696577426f783d223020302033353020343030;
    bytes32 internal constant svgStart3 = 0x223e3c7374796c653e2e62617365207b666f6e742d73697a653a313470783b7d;
    bytes32 internal constant svgStart4 = 0x3c2f7374796c653e3c726563742077696474683d223130302522206865696768;
    bytes32 internal constant svgStart5 = 0x743d2231303025222066696c6c3d227768697465222f3e3c7465787420783d22;
    bytes24 internal constant svgStart6 = 0x31302220793d2232302220636c6173733d2262617365223e;
    
    /// Equal to "</text><text x="10" y="
    bytes23 internal constant svgLinePart1 = 0x3c2f746578743e3c7465787420783d2231302220793d22;
    /// Equal to " class="base">
    bytes15 internal constant svgLinePart2 = 0x2220636c6173733d2262617365223e;
    bytes13 internal constant svgEnd = 0x3c2f746578743e3c2f7376673e;

    bytes32 internal constant tokenUri1 = 0x20226465736372697074696f6e223a2022546f6b656e5377617020496e766f69;
    bytes32 internal constant tokenUri2 = 0x6365222c2022696d616765223a2022646174613a696d6167652f7376672b786d;
    bytes9 internal constant tokenUri3 = 0x6c3b6261736536342c;
    bytes19 internal constant tokenUriStart = 0x7b226e616d65223a2022496e766f6963652023;
    bytes29 internal constant tokenUriData = 0x646174613a6170706c69636174696f6e2f6a736f6e3b6261736536342c;

    /****************************************************************
     *                  ERRORS                                      *
     ****************************************************************/
    /// `msg.value` is too low
    error InvalidValue();
    /// The market already exists
    error Exists();
    /// Invoice has not been issued yet
    error Invalid();
    /// Still has unsused funds
    error FundsAvailable();
    /// The internal account balance is too low for requested action
    error NoFunds();
    /// No market has been created for the selected token
    error NoMarket();
    /// Let's not allow reentrancy
    error NonReentrant();
    /// Please donate direct deposits to buidlguidl.eth
    error NotAllowed();
    /// The requested token transfer was unsuccessful
    error NoTransfer();
    /// Exactly what is says :-\
    error Unauthorized();

    /// Holds data from which invoice SVG can be built
    /// We exclude `cost` here because the price offered by TokenSwap is always `USE_COST`
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
    /// @dev The message value must be 0.005 ether
    function buyAccess() external payable {
        if (accounts[msg.sender] != 0) revert FundsAvailable();
        if (msg.value != 0.005 ether) revert InvalidValue();

        accounts[msg.sender] = 0.004 ether;
        targetFunds = 0.001 ether;
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
    function sellTokens(address targetToken, uint256 amount) external notLocked() {
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

    /// @notice Sell NFTs to the TokenShop for a fixed price
    /// @dev The seller must have approved the TokenShop to transfer the tokens
    /// @param targetToken Address of the token the seller wishes to make a market for
    /// @param tokenIds The ids of the specified tokens the seller wishes to sell
    function sellTokens(address targetToken, uint256[] calldata tokenIds) external notLocked() {
        if (!markets[targetToken]) revert NoMarket();
        if (accounts[msg.sender] < 0.001 ether) revert NoFunds();

        /// Why no input validation on tokenIds?
        /// If there are duplicates it will revert in `safeTransferFrom`

        uint256 numberOfTokens = tokenIds.length;

        accounts[msg.sender] -= 0.001 ether;
        supply++;

        Invoice storage invoice = invoices[supply];
        invoice.seller = msg.sender;
        invoice.token = targetToken;
        invoice.amountOfTokens = numberOfTokens;
        invoice.blocknumber = block.number;

        _mint(msg.sender, supply);

        for (uint256 i; i < numberOfTokens; ) {
            ERC721(targetToken).safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /****************************************************************
     *                   SVG INVOICE VIEWERS                        *
     ****************************************************************/
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
      string memory json = Base64.encode(
        bytes(abi.encodePacked(
            _createURIStart(),
            tokenId.toString(),
            _createURIDescription(),
            Base64.encode(bytes(generateSVGofTokenById(tokenId))), '"}')));

        json = string.concat(_createURIData(), json);
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

        string memory svg = string(abi.encodePacked(_createSVGStart(), invoiceNumberLbl, id.toString(), _createSVGLine(0x003630), sellerLbl, invoices[id].seller.toHexString()));
        svg = string(abi.encodePacked(svg, _createSVGLine(0x003830), tokenLbl, invoices[id].token.toHexString(), _createSVGLine(0x313030)));
        return string(abi.encodePacked(svg, amountLbl, invoices[id].amountOfTokens.toString(), _createSVGMiddle(), invoices[id].blocknumber.toString(), svgEnd));
    }

    /****************************************************************
     *                       HELPERS                                *
     ****************************************************************/

    /// @notice Helper to construct string vir NFT view functions
    /// @dev Creates "</text><text x="10" y="{y}" class="base">
    /// @return SVG line start code
    function _createSVGLine(bytes3 y) internal pure returns (string memory) {
        return string(abi.encode(svgLinePart1, y, svgLinePart2));
    }

    /// @notice Helper to construct string vir NFT view functions
    /// @dev Refer to CONSTANTS natspec for detail
    /// @return SVG file start code
    function _createSVGStart() internal pure returns (string memory) {
        return string(abi.encodePacked(svgStart0, svgStart1, svgStart2, svgStart3, svgStart4, svgStart5, svgStart6, headingLbl, _createSVGLine(0x003430)));
    }

    /// @notice Helper to construct string vir NFT view functions
    /// @dev Refer to CONSTANTS natspec
    /// @return SVG middle template code
    function _createSVGMiddle() internal pure returns (string memory) {
        return string(abi.encodePacked(_createSVGLine(0x313230), paidLbl, priceLbl, _createSVGLine(0x313430), blockLbl));
    }

    /// @notice Helper to construct string vir NFT view functions
    /// @dev Refer to CONSTANTS natspec
    /// @return SVG URI template code
    function _createURIDescription() internal pure returns (string memory) {
        return string(abi.encodePacked(tokenUri1, tokenUri2, tokenUri3));
    }

    /// @notice Helper to construct string vir NFT view functions
    /// @dev Refer to CONSTANTS natspec
    /// @return SVG URI template code
    function _createURIStart() internal pure returns (string memory) {
        return string(abi.encodePacked(tokenUriStart));
    }

    /// @notice Helper to construct string vir NFT view functions
    /// @dev Refer to CONSTANTS natspec
    /// @return SVG data template code
    function _createURIData() internal pure returns (string memory) {
        return string(abi.encodePacked(tokenUriData));
    }

    /****************************************************************
     *                  MANAGEMENT FUNCTIONS                        *
     ****************************************************************/

    /// @notice Allows a beneficiary organization to transfer out tokens
    /// @dev Beneficiaries can be degen too! But caller must audit ERC20 code. 
    /// ASSUME ALL TOKENS ARE HOSTILE UNLESS CONFIRMED OTHERWISE
    function transferTokens(address targetToken, address to, uint256 amount) external notLocked() {
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
    function nominateTarget(address newTarget) external {
        if (msg.sender != target) revert Unauthorized();
        pendingTarget = newTarget;
    }

    /// @notice Allows a nominated beneficiary to accept nomination
    function claimNomination() external {
        if (msg.sender != pendingTarget) revert Unauthorized();
        target = pendingTarget;
        delete pendingTarget;
    }

    /****************************************************************
     *                       MODIFIERS                              *
     ****************************************************************/
    
    /// @notice Minimal non-reentrant fix
    modifier notLocked() {
        if (_locked != 0) revert NonReentrant();
        _locked = 1;
        _;
        _locked = 0;
    }

    /****************************************************************
     *                       MISC                                   *
     ****************************************************************/

    /// @notice The TokenSwap does not accept direct ETH transfers
    receive() payable external {
        revert NotAllowed();
    }

    /// @notice To support `safeTransfer` of ERC721 tokens
    /// @return bytes64 selector
    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        /// There is no reason the TokenSwap contract should hold it's own NFT
        if (msg.sender == address(this)) revert NotAllowed();
        return IERC721Receiver.onERC721Received.selector;
    }
}
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/TokenSwap.sol";
import "../src/mocks/MockToken.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;
    MockToken public token;

    address public user = address(0x20);
    address public beneficiary = address(0x10);

    function setUp() public {
        tokenSwap = new TokenSwap(beneficiary);
        token = new MockToken("Mock Token", "MCK");

        vm.prank(user);
        token.faucet(10 ether);
    }

    function testBuyAccess() public {
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        tokenSwap.buyAccess{value: 0.005 ether}();
        vm.stopPrank();

        assertEq(tokenSwap.accounts(user), 0.004 ether);
    }

    function testBuyAccessInvalidValue(uint256 amount) public {
        vm.startPrank(user);
        vm.assume(amount != 0.005 ether);
        vm.deal(user, amount);
        vm.expectRevert(TokenSwap.InvalidValue.selector);
        tokenSwap.buyAccess{value: amount}();
        vm.stopPrank();
    }

    function testBuyAccessFundsAvailable() public {
        testBuyAccess();
        vm.deal(user, 0.005 ether);
        vm.prank(user);
        vm.expectRevert(TokenSwap.FundsAvailable.selector);
        tokenSwap.buyAccess{value: 0.005 ether}();
    }

    function testMakeMarket() public {
        testBuyAccess();
        vm.startPrank(user);
        tokenSwap.createMarket(address(token));

        assertEq(tokenSwap.markets(address(token)), true);
        vm.stopPrank();
    }

    function testMakeMarketExists() public {
        testMakeMarket();
        vm.startPrank(user);
        vm.expectRevert(TokenSwap.Exists.selector);
        tokenSwap.createMarket(address(token));
    }

    function testCreateMarketNoFunds() public {
        vm.startPrank(user);
        vm.expectRevert(TokenSwap.NoFunds.selector);
        tokenSwap.createMarket(address(token));
    }

    function testSellTokens() public {
        testMakeMarket();
        vm.startPrank(user);
        assertEq(token.balanceOf(user), 10 ether);
        token.approve(address(tokenSwap), 10 ether);
        tokenSwap.sellTokens(address(token), 1 ether);
        assertEq(token.balanceOf(user), 9 ether);
        vm.stopPrank();
    }

    function testSellTokensNoMarket(address market, uint256 amount) public {
        vm.assume(market != address(token));
        testBuyAccess();
        vm.expectRevert(TokenSwap.NoMarket.selector);
        tokenSwap.sellTokens(market, amount);
    }

    function testSellTokensNoFunds(uint256 amount) public {
        testMakeMarket();
        vm.expectRevert(TokenSwap.NoFunds.selector);
        tokenSwap.sellTokens(address(token), amount);
    }

    function testSVG() public {
        testSellTokens();
        string memory svg = tokenSwap.renderTokenById(1);
        console.log(svg);
    }

    function testReceiveEther() public {
        vm.expectRevert(TokenSwap.NotAllowed.selector);
        (bool success, ) = address(tokenSwap).call{value: 1 ether}("");
    }

    function testTransferTokens(uint256 amount, address to) public {
        testSellTokens();
        assumeNoPrecompiles(to);
        vm.assume(amount < 1 ether);
        vm.assume(to != user && to != beneficiary && to != address(0) && to != address(token) && to != address(tokenSwap));
        uint256 balanceBefore = token.balanceOf(to);
        vm.startPrank(beneficiary);
        tokenSwap.transferTokens(address(token), to, amount);
        vm.stopPrank();
        assertEq(token.balanceOf(to) - balanceBefore, amount);
    }

    function testWithdrawFees(address to) public {
        testSellTokens();
        assumePayable(to);
        vm.assume(to != address(0) && to != user && to != address(tokenSwap));
        vm.startPrank(beneficiary);
        tokenSwap.withdrawFees(to);
        vm.stopPrank();
    }

    function testNominateTarget(address target) public {
        vm.assume(target != address(0));
        vm.startPrank(beneficiary);
        tokenSwap.nominateTarget(target);
        assertEq(tokenSwap.pendingTarget(), target);
        vm.stopPrank();
    }

    function testClaimNomination(address target) public {
        vm.assume(target != address(0));
        testNominateTarget(target);
        vm.startPrank(target);
        tokenSwap.claimNomination();
        vm.stopPrank();
        assertEq(tokenSwap.target(), target);
    }

    function testSVGURI() public {
        testSellTokens();
        string memory svg = tokenSwap.renderTokenById(1);
        console.log(svg);
    }
    /** TO DO: 
     1. More tests
     2. Try to break it
     */
}
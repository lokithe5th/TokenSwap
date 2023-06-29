pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/TokenSwap.sol";
import "../src/mocks/MockToken.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;
    MockToken public token;

    address public user = address(0x20);

    function setUp() public {
        tokenSwap = new TokenSwap(address(0x10));
        token = new MockToken("Mock Token", "MCK");

        vm.prank(user);
        token.faucet(10 ether);
    }

    function testBuyAccess() public {
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        tokenSwap.buyAccess{value: 0.005 ether}();
        vm.stopPrank();

        assertEq(tokenSwap.accounts(user), 0.005 ether);
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
    }

    function testSellTokensNoMarket(address market, uint256 amount) public {
        vm.assume(market != address(token));
        testBuyAccess();
        vm.expectRevert(TokenSwap.NoMarket.selector);
        tokenSwap.sellTokens(market, amount);
    }

    function testSVG() public {
        testSellTokens();
        string memory svg = tokenSwap.renderTokenById(1);
        console.log(svg);
    }
}
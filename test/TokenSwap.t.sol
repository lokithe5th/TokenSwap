pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/TokenSwap.sol";
import "../src/mocks/MockToken.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;
    MockToken public token;

    function setUp() public {
        tokenSwap = new TokenSwap(address(0x10));
        token = new MockToken("Mock Token", "MCK");

        vm.prank(address(0x20));
        token.faucet(10 ether);
    }

    function testBuyAccess() public {
        vm.startPrank(address(0x20));
        vm.deal(address(0x20), 1 ether);
        tokenSwap.buyAccess{value: 0.005 ether}();
        vm.stopPrank();

        assertEq(tokenSwap.accounts(address(0x20)), 0.005 ether);
    }

    function testMakeMarket() public {
        testBuyAccess();
        vm.startPrank(address(0x20));
        tokenSwap.createMarket(address(token));

        assertEq(tokenSwap.markets(address(token)), true);
    }

    function testSellTokens() public {
        testMakeMarket();
        vm.startPrank(address(0x20));
        assertEq(token.balanceOf(address(0x20)), 10 ether);
        token.approve(address(tokenSwap), 10 ether);
        tokenSwap.sellTokens(address(token), 1 ether);
        assertEq(token.balanceOf(address(0x20)), 9 ether);
    }

    function testSVG() public {
        testSellTokens();
        string memory svg = tokenSwap.renderTokenById(1);
        console.log(svg);
    }
}
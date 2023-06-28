pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/TokenSwap.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;

    function setUp() public {
        tokenSwap = new TokenSwap(address(0x10));
    }

    function testBuyAccess() public {
        vm.startPrank(address(0x20));
        vm.deal(address(0x20), 1 ether);
        tokenSwap.buyAccess{value: 0.005 ether}();
        vm.stopPrank();

        assertEq(tokenSwap.accounts(address(0x20)), 0.005 ether);
    }
}
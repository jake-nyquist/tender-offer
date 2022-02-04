// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../TenderOffer.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface CheatCodes {
    function prank(address) external;

    function expectRevert(bytes calldata) external;
}

contract TenderOfferTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    TenderOffer to;
    ERC20 token;

    // The state of the contract gets reset before each
    // test is run, with the `setUp()` function being called
    // each time after deployment.
    function setUp() public {
        token = new ERC20("test_token", "TKN");
        to = new TenderOffer(address(1), address(token), 10, 10);
    }

    // A simple unit test
    function testTransferNotOwner() public {
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        cheats.prank(address(0));

        to.transferOwnership(address(2));
    }
}

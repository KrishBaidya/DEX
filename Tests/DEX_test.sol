// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "remix_tests.sol";
import "../DEX.sol";
import "../MEME.sol";

contract DEXTest {
    DEX dex;
    MEME meme;
    
    function beforeEach() public {
        meme = new MEME();
        dex = new DEX(address(meme));

        meme.transfer(msg.sender , 100000000);
    }
    
    function testStack() public {
        // Ensure initial stacking rate is 0
        Assert.equal(dex.stackingRate(), 0, "Initial stacking rate should be 0");
        
        // Transfer some MEME tokens to the contract
        // meme.transfer(address(dex), 10000000);
        
        // Stack some tokens
        dex.stack{value: 10000}(1000000);
        
        // Ensure stacking rate is set correctly
        Assert.equal(dex.stackingRate(), 1000000000 / 1000000 * 10**18, "Stacking rate should be set correctly");
        
        // Ensure user's stack is recorded correctly
        (uint meme_amount , uint eth_amount , ) = dex.Stacked(address(this));
        Assert.equal(meme_amount, 1000000, "User's MEME amount should be recorded correctly");
        Assert.equal(eth_amount, 1000000000, "User's ETH amount should be recorded correctly");
        
        // Try to stack more tokens than allowed by the current rate (should fail)
        (bool success,) = address(dex).call{value: 1000000000}(abi.encodeWithSignature("stack(uint256)", 100000000));
        Assert.equal(success, false, "Stacking more tokens than allowed by the current rate should fail");
    }
    
    function testUnstack() public {
        // Transfer some MEME tokens to the contract
        meme.transfer(address(dex), 10000000);
        
        // Stack some tokens
        dex.stack{value: 1000000000}(1000000);
        
        // Unstack some tokens
        dex.unstack(500000);
        
        // Ensure user's stack is updated correctly
        (uint meme_amount , uint eth_amount , ) = dex.Stacked(address(this));
        Assert.equal(meme_amount, 500000, "User's MEME amount should be updated correctly");
        Assert.equal(eth_amount, 500000000, "User's ETH amount should be updated correctly");
        
        // Ensure stacking rate is updated correctly
        Assert.equal(dex.stackingRate(), 1000000000 / 500000 * 10**18, "Stacking rate should be updated correctly");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "remix_tests.sol";
import "../DEX.sol";
import "../MEME.sol";

contract DEXTest {
    MEME meme = new MEME();
    DEX dex = new DEX(address(meme));
    uint256 balance;

    function beforeAll() public{
        meme.approve(address(this) , 1000000000000000000000000000);
        balance = meme.balanceOf(address(this));
        
    }
    /// #value: 20000000000000
    function stack() public payable{
        (uint meme_amount , uint eth_amount , ) = dex.Stacked(address(this));
        Assert.equal(meme_amount , 0 , "should be equal");
        Assert.equal(eth_amount , 0 , "should be equal");
        dex.stack{value: msg.value}(balance);
        (meme_amount , eth_amount , ) = dex.Stacked(address(this));
        Assert.equal(meme_amount , balance , "should be equal");
        Assert.equal(eth_amount , 20000000000000 , "should be equal");
    }
}

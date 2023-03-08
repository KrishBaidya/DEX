// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "remix_tests.sol";
import "../DEX.sol";
import "../MEME.sol";



contract DEXTest {
    DEX dex;
    address tokenAddress;
    uint256 tokenSupply;

    function beforeAll() public {
        tokenSupply = 1000;
        MEME token = new MEME();
        tokenAddress = address(token);
        dex = new DEX(tokenAddress);
    }

    function beforeEach() public {
        dex.pause();
    }

    function testStack() public payable {
        uint256 tokenAmount = 100;
        uint256 ethAmount = 10;
        (bool success, bytes memory result) = address(dex).call{value: ethAmount}(abi.encodeWithSignature("stack(uint256)", tokenAmount));
        Assert.ok(success, "Stack failed");
        Assert.equal(dex.Stacked(msg.sender).meme_amount, tokenAmount, "Wrong token amount stacked");
        Assert.equal(dex.Stacked(msg.sender).eth_amount, ethAmount, "Wrong eth amount stacked");
        Assert.equal(dex.Stacked(msg.sender).time, block.timestamp, "Wrong stack time");
    }

    function testStackPaused() public payable {
        dex.pause();
        uint256 tokenAmount = 100;
        uint256 ethAmount = 10;
        (bool success, bytes memory result) = address(dex).call{value: ethAmount}(abi.encodeWithSignature("stack(uint256)", tokenAmount));
        Assert.isFalse(success, "Stack should have failed");
    }

    function testUnstack() public payable {
        uint256 tokenAmount = 100;
        uint256 ethAmount = 10;
        (bool success, bytes memory result) = address(dex).call{value: ethAmount}(abi.encodeWithSignature("stack(uint256)", tokenAmount));
        Assert.isTrue(success, "Stack failed");

        uint256 unstackTokenAmount = 50;
        (success, result) = address(dex).call(abi.encodeWithSignature("unstack(uint256)", unstackTokenAmount));
        Assert.isTrue(success, "Unstack failed");
        Assert.equal(dex.Stacked(msg.sender).meme_amount, tokenAmount - unstackTokenAmount, "Wrong token amount unstacked");
        Assert.equal(dex.Stacked(msg.sender).eth_amount, ethAmount - (ethAmount * unstackTokenAmount / tokenAmount), "Wrong eth amount unstacked");
        Assert.equal(dex.Stacked(msg.sender).time, block.timestamp, "Wrong unstack time");
    }

    function testUnstackPaused() public payable {
        uint256 tokenAmount = 100;
        uint256 ethAmount = 10;
        (bool success, bytes memory result) = address(dex).call{value: ethAmount}(abi.encodeWithSignature("stack(uint256)", tokenAmount));
        Assert.isTrue(success, "Stack failed");

        dex.pause();
        uint256 unstackTokenAmount = 50;
        (success, result) = address(dex).call(abi.encodeWithSignature("unstack(uint256)", unstackTokenAmount));
        Assert.isFalse(success, "Unstack should have failed");
    }
}

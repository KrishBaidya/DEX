// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "MEME.sol";

struct Stack_Struct {
    uint256 meme_amount;
    uint256 eth_amount;
    uint256 time;
}

contract DEX is Pausable, Ownable {
    ERC20 meme;

    mapping(address => Stack_Struct) public Stacked;

    uint256 public memeBalance = 10000000000000000;
    uint256 public ethBalance = 10000000000000000;

    uint256 public _k;
    uint256 public _x;
    uint256 public _y;

    constructor(address addr) {
        meme = MEME(addr);

        //_stack(10000000, 10000000);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _updateK() internal {
        _k = _x * _y;
    }

    function _stack(uint256 meme_amount) public payable {
        meme.transferFrom(msg.sender, address(this), meme_amount);
        
        _x += meme_amount;
        _y += msg.value;

        // Stack_Struct memory ss = Stack_Struct(
        //     meme_amount,
        //     eth_amount,
        //     block.timestamp
        // );
        Stacked[msg.sender].meme_amount += meme_amount;
        Stacked[msg.sender].eth_amount += msg.value;
        Stacked[msg.sender].time = block.timestamp;

        _updateK();
    }

    function _unstack(uint256 meme_amount, uint256 eth_amount) public payable {
        meme.transfer(msg.sender, meme_amount);
        //memeBalance += meme_amount;
        payable(msg.sender).transfer(eth_amount);
        // ethBalance += eth_amount;

        _x -= meme_amount;
        _y -= eth_amount;

        Stacked[msg.sender].meme_amount -= meme_amount;
        Stacked[msg.sender].eth_amount -= eth_amount;
        Stacked[msg.sender].time = block.timestamp;

        _updateK();
    }

    function _buy(uint128 meme_amount) public payable {
        uint dx = meme_amount;
        uint dy = _y;

        _x += dx;
        _y = _k / _x;

        dy -= _y;

        memeBalance += dx;
        ethBalance -= dy;
    }

    function _sell(uint128 meme_amount) public payable {
        uint256 dx = meme_amount;
        uint256 dy = _y;

        _x -= dx;
        _y = _k / _x;

        dy = _y - dy;

        memeBalance -= dx;
        ethBalance += dy;
    }
}

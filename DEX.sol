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

    uint256 public stackingRate;

    uint256 public _k;
    uint256 public _x;
    uint256 public _y;

    uint256 public precision = 10**18;

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

    function stack(uint256 meme_amount) public payable {
        require(stackingRate <= (msg.value * precision / meme_amount));
        _stack(meme_amount);
    }

    function unstack(uint256 meme_amount) public {
        uint256 meme_amount2 = _x - meme_amount;
        uint256 eth_amount2 = ((stackingRate * meme_amount) / precision);
        _unstack(meme_amount, eth_amount2, msg.sender);
    }

    function _stack(uint256 meme_amount) internal {
        meme.transferFrom(msg.sender, address(this), meme_amount);

        _x += meme_amount;
        _y += msg.value;

        Stacked[msg.sender].meme_amount += meme_amount;
        Stacked[msg.sender].eth_amount += msg.value;
        Stacked[msg.sender].time = block.timestamp;

        stackingRate = ((_y * precision) / _x);

        _updateK();
    }

    function _unstack(
        uint256 meme_amount,
        uint256 eth_amount,
        address to
    ) public {
        _x -= meme_amount;
        _y -= eth_amount;

        Stacked[to].meme_amount -= meme_amount;
        Stacked[to].eth_amount -= eth_amount;
        Stacked[to].time = block.timestamp;

        meme.transfer(to, meme_amount);
        payable(to).transfer(eth_amount);

        if (_x == 0) {
            stackingRate = 0;
        } else {
            stackingRate = (_y * precision) / _x;
        }

        _updateK();
    }

    // function _buy(uint128 meme_amount) public payable {
    //     uint dx = meme_amount;
    //     uint dy = _y;

    //     _x += dx;
    //     _y = _k / _x;

    //     dy -= _y;

    //     memeBalance += dx;
    //     ethBalance -= dy;
    // }

    // function _sell(uint128 meme_amount) public payable {
    //     uint256 dx = meme_amount;
    //     uint256 dy = _y;

    //     _x -= dx;
    //     _y = _k / _x;

    //     dy = _y - dy;

    //     memeBalance -= dx;
    //     ethBalance += dy;
    // }
}

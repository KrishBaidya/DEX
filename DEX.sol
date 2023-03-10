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

    mapping(address => Stack_Struct[]) public Stacked;

    uint256 public stackingRate;

    uint256 public _k;
    uint256 public _x;
    uint256 public _y;

    uint256 public precision = 10**18;

    uint256 public taxRate = (3 * precision) / 1000;

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
        require(meme_amount > 0, "Send more MEME");
        require(msg.value > 0, "Send more ETH");
        require(
            stackingRate <= (msg.value * precision) / meme_amount,
            "Stacking Rate not met"
        );
        _stack(meme_amount, msg.value);
    }

    function unstack(uint256 index) public {
        require(index >= 0, "Index can't be less then 0");
        _unstack(index);
    }

    function _stack(uint256 meme_amount, uint256 eth_amount) internal {
        meme.transferFrom(msg.sender, address(this), meme_amount);
        _x += meme_amount;
        _y += eth_amount;

        Stack_Struct memory ss = Stack_Struct(
            meme_amount,
            eth_amount,
            block.timestamp
        );
        Stacked[msg.sender].push(ss);

        stackingRate = ((_y * precision) / _x);

        _updateK();
    }

    function _unstack(uint256 index) internal {
        Stack_Struct memory ss = Stacked[msg.sender][index];

        uint256 timestamp = block.timestamp - ss.time;
        uint256 poolShare = ((ss.meme_amount * taxRate * timestamp) / _x);

        uint256 meme_to_return = (poolShare * _x) / _k;
        uint256 eth_to_return = (poolShare * _y) / _k;

        _x -= meme_to_return;
        _y -= eth_to_return;

        meme.transfer(msg.sender, meme_to_return);
        payable(msg.sender).transfer(eth_to_return);

        if (_x == 0) {
            stackingRate = 0;
        } else {
            stackingRate = (_y * precision) / _x;
        }

        _removeArr(index);

        _updateK();
    }

    function _removeArr(uint256 index) internal {
        for (uint256 i = index; i < Stacked[msg.sender].length - 1; i++) {
            Stacked[msg.sender][i] = Stacked[msg.sender][i + 1];
        }
        Stacked[msg.sender].pop();
    }

    // function secondsToDays(uint256 second) public pure returns (uint256) {
    //     return second / 1 days;
    // }

    // function check(uint256 index) public view returns (uint256) {
    //     Stack_Struct memory ss = Stacked[msg.sender][index];

    //     uint256 timestamp = block.timestamp - ss.time;
    //     uint256 poolShare = ((ss.meme_amount * taxRate * timestamp) / _x);

    //     return poolShare;
    // }
}

// pragma solidity ^0.8.9;

// import "@openzeppelin/contracts/security/Pausable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "MEME.sol";

// struct Stack_Struct {
//     uint256 meme_amount;
//     uint256 eth_amount;
//     uint256 time;
//     uint256 stackingRate;
// }

// contract DEX is Pausable, Ownable {
//     ERC20 meme;

//     mapping(address => Stack_Struct) public Stacked;

//     uint256 public stackingRate;

//     uint256 public _k;
//     uint256 public _x;
//     uint256 public _y;

//     uint256 public precision = 10**18;

//     constructor(address addr) {
//         meme = MEME(addr);

//         //_stack(10000000, 10000000);
//     }

//     function pause() public onlyOwner {
//         _pause();
//     }

//     function unpause() public onlyOwner {
//         _unpause();
//     }

//     function _updateK() internal {
//         _k = _x * _y;
//     }

//     function stack(uint256 meme_amount) public payable {
//         require(0 < msg.value , "Eth can't be 0");
//         require(0 < meme_amount , "Meme can't be 0");
//         // if(Stacked[msg.sender].stackingRate != 0){
//         // }
//         require(stackingRate <= ((msg.value * precision) / meme_amount));
//         _stack(meme_amount);
//     }

//     function unstack(uint256 meme_amount) public {
//         require(0 < meme_amount , "Meme can't be 0");

//         uint256 eth_amount2 = ((Stacked[msg.sender].stackingRate * meme_amount) / precision);
//         _unstack(meme_amount, eth_amount2, msg.sender);
//     }

//     function _stack(uint256 meme_amount) internal {
//         meme.transferFrom(msg.sender, address(this), meme_amount);

//         _x += meme_amount;
//         _y += msg.value;

//         Stacked[msg.sender].meme_amount += meme_amount;
//         Stacked[msg.sender].eth_amount += msg.value;
//         Stacked[msg.sender].time = block.timestamp;

//         Stacked[msg.sender].stackingRate = ((_y * precision) / _x);
//         stackingRate = Stacked[msg.sender].stackingRate;

//         _updateK();
//     }

//     function _unstack(
//         uint256 meme_amount,
//         uint256 eth_amount,
//         address to
//     ) public {
//         _x -= meme_amount;
//         _y -= eth_amount;

//         Stacked[to].meme_amount -= meme_amount;
//         Stacked[to].eth_amount -= eth_amount;
//         Stacked[to].time = block.timestamp;

//         meme.transfer(to, meme_amount);
//         payable(to).transfer(eth_amount);

//         if (_x == 0) {
//             Stacked[msg.sender].stackingRate = 0;
//             stackingRate = 0;
//         } else {
//             Stacked[msg.sender].stackingRate = (_y * precision) / _x;
//             stackingRate = Stacked[msg.sender].stackingRate;
//         }

//         _updateK();
//     }

//     // function _buy(uint128 meme_amount) public payable {
//     //     uint dx = meme_amount;
//     //     uint dy = _y;

//     //     _x += dx;
//     //     _y = _k / _x;

//     //     dy -= _y;

//     //     memeBalance += dx;
//     //     ethBalance -= dy;
//     // }

//     // function _sell(uint128 meme_amount) public payable {
//     //     uint256 dx = meme_amount;
//     //     uint256 dy = _y;

//     //     _x -= dx;
//     //     _y = _k / _x;

//     //     dy = _y - dy;

//     //     memeBalance -= dx;
//     //     ethBalance += dy;
//     // }
// }

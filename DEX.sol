// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "MEME.sol";

contract DEX is Pausable, Ownable {
    struct Stack_Struct {
        uint256 meme_amount;
        uint256 eth_amount;
        uint256 time;
    }
    ERC20 meme;

    event Buy(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event Sell(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event Stack(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event UnStack(
        address indexed from,
        uint256 Meme_amount,
        uint256 eth_amount
    );

    mapping(address => Stack_Struct[]) internal Stacked;

    mapping(uint256 => uint256) internal dailyTax;

    uint256 internal stackingRate;

    uint256 internal _k;
    uint256 internal _x;
    uint256 internal _y;

    uint256 internal precision = 10e18;

    uint256 internal taxRate = (3 * precision) / 10;

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

    function getStacks() public view returns (Stack_Struct[] memory) {
        return Stacked[msg.sender];
    }

    function stack(uint256 meme_amount) public payable whenNotPaused{
        require(meme_amount > 0, "Send more MEME");
        require(msg.value > 0, "Send more ETH");
        require(
            stackingRate <= (msg.value * precision) / meme_amount,
            "Stacking Rate not met"
        );
        _stack(meme_amount, msg.value);
    }

    function unstack(uint256 index) public whenNotPaused{
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
        emit Stack(msg.sender, meme_amount, msg.value);
    }

    function _unstack(uint256 index) internal {
        Stack_Struct memory ss = Stacked[msg.sender][index];
        uint256 tax = _distributeTax();

        uint256 meme_to_return = ss.meme_amount;
        uint256 eth_to_return = ss.eth_amount + tax;

        require(
            meme.balanceOf(address(this)) >= meme_to_return,
            "Sorry Currently this contract doesn't have Meme to return, Check back Soon!"
        );
        require(
            address(this).balance >= eth_to_return,
            "Sorry Currently this contract doesn't have Eth to return, Check back Soon!"
        );

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
        emit UnStack(msg.sender, meme_to_return, eth_to_return);
    }

    function _removeArr(uint256 index) internal {
        require(index < Stacked[msg.sender].length, "Index out of bounds");
        for (uint256 i = index; i < Stacked[msg.sender].length - 1; i++) {
            Stacked[msg.sender][i] = Stacked[msg.sender][i + 1];
        }
        Stacked[msg.sender].pop();
    }

    function _distributeTax() internal view returns (uint256) {
        uint256 taxShare = 0;
        if (dailyTax[block.timestamp / 1 days] > 0) {
            Stack_Struct[] storage stacks = Stacked[msg.sender];
            uint256 numStacks = stacks.length;
            uint256 totalStackTime = 0;
            for (uint256 i = 0; i < numStacks; i++) {
                Stack_Struct memory ss = stacks[i];
                totalStackTime += (block.timestamp - ss.time);
            }
            for (uint256 i = 0; i < numStacks; i++) {
                Stack_Struct memory ss = stacks[i];
                uint256 poolShare = ((ss.meme_amount * precision) / _x);
                uint256 stackTime = (block.timestamp - ss.time);
                uint256 stackWeight = stackTime / totalStackTime;
                taxShare +=
                    (poolShare *
                        dailyTax[block.timestamp / 1 days] *
                        stackWeight) /
                    _k;
            }
        }
        return taxShare;
    }

    function getMemePrice(uint256 meme_amount) public whenNotPaused view returns (uint256) {
        require(_k > 0, "Not enough liquidity");
        uint256 dx = 0;
        uint256 dy = 0;
        if (_y == 0) {
            dx = _k / 1 - meme_amount;
        } else {
            dx = _k / _y - meme_amount;
        }
        if (dx == 0) {
            dy = _k / 1;
        } else {
            dy = _k / dx;
        }
        uint256 eth_price_without_tax = dy - _y;
        uint256 eth_tax = (eth_price_without_tax * taxRate) / precision;

        uint256 eth_price_with_tax = eth_price_without_tax + eth_tax;
        return eth_price_with_tax;
    }

    function getETHPrice(uint256 eth_amount) public whenNotPaused view returns (uint256) {
        require(_k > 0, "Not enough liquidity");
        uint256 dx = 0;
        uint256 dy = 0;
        if (_x == 0) {
            dy = _k / 1 - eth_amount;
        } else {
            dy = _k / _x - eth_amount;
        }
        if (dy == 0) {
            dx = _k / 1;
        } else {
            dx = _k / dy;
        }
        uint256 meme_price_without_tax = dx - _x;
        uint256 meme_tax = (meme_price_without_tax * taxRate) / precision;

        uint256 meme_price_with_tax = meme_price_without_tax - meme_tax;

        return meme_price_with_tax;
    }

    function buy(uint256 meme_amount) public whenNotPaused payable {
        require(meme_amount > 0, "Send Some Meme");
        uint256 meme_price = getMemePrice(meme_amount);
        require(meme_price <= msg.value, "Send More ETH");

        meme.transfer(msg.sender, meme_amount);
        payable(msg.sender).transfer(msg.value - meme_price);

        dailyTax[block.timestamp / 1 days] +=
            (meme_amount * (precision + taxRate)) /
            precision;

        _x -= meme_amount;
        _y = (_k / _x);

        emit Buy(msg.sender, meme_amount, meme_price);
    }

    function sell(uint256 eth_amount) public whenNotPaused{
        require(eth_amount > 0, "Send Some ETH");
        uint256 eth_price = getETHPrice(eth_amount);

        require(eth_price <= meme.balanceOf(msg.sender), "You don't have enough meme");
        meme.transferFrom(msg.sender, address(this), eth_price);
        payable(msg.sender).transfer(eth_amount);

        dailyTax[block.timestamp / 1 days] +=
            (eth_price * (precision + taxRate)) /
            precision;

        _y -= eth_amount;
        _x = (_k / _y);

        emit Sell(msg.sender, eth_price, eth_amount);
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

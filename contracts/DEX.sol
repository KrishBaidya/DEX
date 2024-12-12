// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MEME.sol";

import "hardhat/console.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

using SafeERC20 for IERC20;

contract DEX is Pausable, Ownable {
    struct Stack_Struct {
        uint256 meme_amount;
        uint256 eth_amount;
        uint256 time;
    }
    IERC20 immutable meme;

    event Buy(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event Sell(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event Stack(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event UnStack(
        address indexed from,
        uint256 Meme_amount,
        uint256 eth_amount
    );
    event Withdrawal(address, uint256);

    mapping(address => Stack_Struct[]) internal Stacked;

    mapping(uint256 => uint256) public dailyTax;

    uint256 public stackingRate;

    uint256 internal _k;
    uint256 internal _x;
    uint256 internal _y;

    uint256 internal constant precision = 10e18;

    uint256 public immutable taxRate = (3 * precision) / 1000;

    address routerAddress;

    modifier onlyRouter() {
        require(
            msg.sender == routerAddress,
            "Only the router can call this function"
        );
        _;
    }

    function setRouter(address _routerAddress) internal onlyOwner {
        routerAddress = _routerAddress;
    }

    constructor(
        address initialOwner,
        address addr,
        uint256 _taxrate
    ) Ownable(initialOwner) {
        meme = MEME(addr);
        taxRate = (_taxrate * precision) / 1000;

        originalX = _x;

        setRouter(initialOwner);
        //_stack(10000000, 10000000);
    }

    receive() external payable {}

    fallback() external payable {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _updateK() internal {
        _k = _x * _y;
    }

    function getStacks() public view returns (Stack_Struct[] memory) {
        return Stacked[msg.sender];
    }

    function stack(uint256 meme_amount) public payable whenNotPaused {
        require(meme_amount > 0, "Send more MEME");
        require(msg.value > 0, "Send more ETH");
        require(
            stackingRate <= (msg.value * precision) / meme_amount,
            "Stacking Rate not met"
        );
        _stack(meme_amount, msg.value);
    }

    function unstack(uint256 index) public whenNotPaused {
        // require(index >= 0, "Index can't be less then 0");
        _unstack(index);
    }

    function _stack(uint256 meme_amount, uint256 eth_amount) internal {
        meme.safeTransferFrom(msg.sender, address(this), meme_amount);
        _x += meme_amount;
        _y += eth_amount;

        Stack_Struct memory ss = Stack_Struct(
            meme_amount,
            eth_amount,
            block.timestamp
        );
        Stacked[msg.sender].push(ss);

        stackingRate = ((_y * precision) / _x);

        originalX = _x;

        _updateK();
        emit Stack(msg.sender, meme_amount, msg.value);
    }

    uint256 internal originalX;

    function _unstack(uint256 index) internal {
        require(index < Stacked[msg.sender].length, "Index out of bounds");

        Stack_Struct memory ss = Stacked[msg.sender][index];

        uint256 tax = _distributeTax(index);
        uint256 meme_to_return = ss.meme_amount;
        uint256 eth_to_return = ss.eth_amount + tax;
        originalX = _x;

        require(
            meme_to_return <= meme.balanceOf(address(this)),
            "Sorry Currently this contract doesn't have Meme to return, Check back Soon!"
        );
        require(
            eth_to_return <= address(this).balance,
            "Sorry Currently this contract doesn't have Eth to return, Check back Soon!"
        );

        _x = (_x >= meme_to_return) ? (_x - meme_to_return) : 0;
        _y = (_y >= eth_to_return) ? (_y - eth_to_return) : 0;

        if (_x == 0) {
            stackingRate = 0;
        } else {
            stackingRate = (_y * precision) / _x;
        }

        _removeArr(index);
        _updateK();

        emit UnStack(msg.sender, meme_to_return, eth_to_return);

        meme.safeTransfer(msg.sender, meme_to_return);
        payable(msg.sender).transfer(eth_to_return);
    }

    function _removeArr(uint256 index) internal {
        require(index < Stacked[msg.sender].length, "Index out of bounds");
        for (uint256 i = index; i < Stacked[msg.sender].length - 1; i++) {
            Stacked[msg.sender][i] = Stacked[msg.sender][i + 1];
        }
        Stacked[msg.sender].pop();
    }

    function _distributeTax(uint256 poolIndex) public view returns (uint256) {
        uint256 taxShare = 0;
        if (dailyTax[block.timestamp / 1 days] > 0) {
            Stack_Struct[] memory stacks = Stacked[msg.sender];
            require(poolIndex < stacks.length, "Invalid pool index");

            Stack_Struct memory ss = stacks[poolIndex];
            uint256 poolShare = ss.meme_amount;

            uint256 creationTime = ss.time;
            uint256 currentDay = block.timestamp / 1 days;

            for (
                uint256 day = creationTime / 1 days;
                day <= currentDay;
                day++
            ) {
                taxShare += (poolShare * dailyTax[day]) / originalX;
            }
        }
        return taxShare;
    }

    function getMemePrice(
        uint256 meme_amount
    ) public view whenNotPaused returns (uint256) {
        require(_k > 0, "Not enough liquidity");
        require(_y > 0, "Not enough ETH liquidity"); // Check for zero liquidity

        uint256 dx = _k / _y; // Calculate dy based on the liquidity pool state
        require(
            dx > meme_amount,
            "Insufficient liquidity for this MEME amount"
        ); // Ensure dx is greater than meme_amount
        dx = dx - meme_amount;

        uint256 dy = _k / dx;

        uint256 eth_price_without_tax = dy - _y;
        uint256 eth_tax = (eth_price_without_tax * taxRate) / precision;

        uint256 eth_price_with_tax = eth_price_without_tax + eth_tax;
        return eth_price_with_tax;
    }

    function calculateTax(uint256 meme_amount) internal view returns (uint256) {
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

        return eth_tax;
    }

    function getETHPrice(
        uint256 eth_amount
    ) public view whenNotPaused returns (uint256) {
        require(_k > 0, "Not enough liquidity");
        require(_x > 0, "Not enough MEME liquidity");

        uint256 dy = _k / _x; // Calculate dy based on the liquidity pool state
        require(dy > eth_amount, "Insufficient liquidity for this ETH amount"); // Ensure dy is greater than eth_amount

        dy = dy - eth_amount; // Subtract eth_amount from dy, ensuring it's still positive

        uint256 dx = _k / dy; // Calculate dx from the new dy

        uint256 meme_price_without_tax = dx - _x;
        uint256 meme_tax = (meme_price_without_tax * taxRate) / precision;

        uint256 meme_price_with_tax = meme_price_without_tax >= meme_tax
            ? meme_price_without_tax - meme_tax
            : 0;

        return meme_price_with_tax;
    }

    function buy(
        address user,
        uint256 meme_amount
    ) external payable whenNotPaused onlyRouter {
        require(user != address(0), "Zero Address");
        require(meme_amount > 0, "Send Some Meme");
        uint256 meme_price = getMemePrice(meme_amount);
        require(meme_price <= msg.value, "Send More ETH");

        dailyTax[block.timestamp / 1 days] += calculateTax(meme_amount);

        _x -= meme_amount;
        _y = (_k / _x);

        emit Buy(user, meme_amount, meme_price);

        // Use user address instead of msg.sender
        meme.safeTransfer(user, meme_amount);
        payable(user).transfer(msg.value - meme_price);
    }

    function sell(
        address user,
        uint256 eth_amount
    ) external whenNotPaused onlyRouter {
        require(eth_amount > 0, "Send Some ETH");

        // Calculate the required amount of MEME to sell based on the ETH amount
        uint256 eth_price = getETHPrice(eth_amount);

        // Ensure the sender has enough MEME tokens
        require(
            eth_price <= meme.balanceOf(user),
            "You don't have enough meme"
        );

        // Ensure the sender has approved enough MEME tokens for the DEX contract to transfer
        uint256 allowance = meme.allowance(user, address(this));
        require(
            allowance >= eth_price,
            string.concat(
                "You don't have enough meme approved ",
                Strings.toString(eth_price)
            )
        );

        // Adjust the state variables for the DEX (e.g., liquidity pool)
        _y -= eth_amount;
        _x = (_k / _y);

        // Emit the Sell event
        emit Sell(user, eth_price, eth_amount);

        // Perform the transfer of MEME tokens and ETH
        meme.safeTransfer(address(this), eth_price);

        pendingWithdrawals[user] += eth_amount;
    }

    mapping(address => uint256) private pendingWithdrawals;

    function withdraw(address user) external {
        require(user != address(0), "Zero Address");
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        emit Withdrawal(user, amount);

        pendingWithdrawals[user] = 0;
        (bool success, ) = user.call{value: amount}("");
        require(success, "Failed to send Ether");
    }
}

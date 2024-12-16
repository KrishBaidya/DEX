// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MEME.sol";

import "hardhat/console.sol";

contract Pool is Pausable, Ownable {
    using SafeERC20 for IERC20;

    struct Stack_Struct {
        uint256 meme_amount;
        uint256 eth_amount;
        uint256 time;
    }

    IERC20 public immutable meme;

    event Stack(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event UnStack(
        address indexed from,
        uint256 Meme_amount,
        uint256 eth_amount
    );
    event Withdrawal(address indexed to, uint256 amount);

    mapping(address => Stack_Struct[]) internal Stacked;
    mapping(uint256 => uint256) public dailyTax;
    mapping(address => uint256) public pendingWithdrawals;

    uint256 public stackingRate;
    uint256 internal _k;
    uint256 internal _x;
    uint256 internal _y;
    uint256 public taxRate;
    uint256 internal constant precision = 10e18;
    uint256 internal originalX;

    constructor(
        address initialOwner,
        address addr,
        uint256 _taxrate
    ) Ownable(initialOwner) {
        meme = MEME(addr);
        taxRate = (_taxrate * precision) / 1000;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _updateK() internal {
        _k = _x * _y;
    }

    function getK() public view returns (uint256) {
        return _k;
    }

    function getX() public view returns (uint256) {
        return _x;
    }

    function getY() public view returns (uint256) {
        return _y;
    }

    mapping(address => bool) public authorizedContracts;

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized");
        _;
    }

    function addAuthorizedContract(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = true;
    }

    function removeAuthorizedContract(
        address contractAddress
    ) external onlyOwner {
        authorizedContracts[contractAddress] = false;
    }

    function updatePoolState(
        uint256 newX,
        uint256 newY,
        uint256 newK
    ) external onlyAuthorized {
        _x = newX;
        _y = newY;
        _k = newK;
        _updateK(); // Ensure internal consistency
    }

    function getStacks() public view returns (Stack_Struct[] memory) {
        return Stacked[msg.sender];
    }

    function addLiquidity(uint256 meme_amount) public payable whenNotPaused {
        require(meme_amount > 0, "Send more MEME");
        require(msg.value > 0, "Send more ETH");
        require(
            stackingRate <= (msg.value * precision) / meme_amount,
            "Stacking Rate not met"
        );
        _stack(meme_amount, msg.value);
    }

    function removeLiquidity(uint256 index) public whenNotPaused {
        require(index < Stacked[msg.sender].length, "Invalid index");
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
        emit Stack(msg.sender, meme_amount, eth_amount);
    }

    function _unstack(uint256 index) internal {
        require(index < Stacked[msg.sender].length, "Index out of bounds");

        Stack_Struct memory ss = Stacked[msg.sender][index];

        uint256 tax = _distributeTax(index);
        uint256 meme_to_return = ss.meme_amount;
        uint256 eth_to_return = ss.eth_amount + tax;

        require(
            meme_to_return <= meme.balanceOf(address(this)),
            "Insufficient MEME balance"
        );
        require(
            eth_to_return <= address(this).balance,
            "Insufficient ETH balance"
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

    function _distributeTax(uint256 stackIndex) public view returns (uint256) {
        uint256 taxShare = 0;
        if (dailyTax[block.timestamp / 1 days] > 0) {
            Stack_Struct[] memory stacks = Stacked[msg.sender];
            require(stackIndex < stacks.length, "Invalid pool index");

            Stack_Struct memory ss = stacks[stackIndex];
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

    function getMemePrice(
        uint256 meme_amount
    ) public view whenNotPaused returns (uint256) {
        require(_k > 0, "Not enough liquidity");
        require(_y > 0, "Not enough ETH liquidity");

        uint256 dx = _k / _y;
        require(
            dx > meme_amount,
            "Insufficient liquidity for this MEME amount"
        );
        dx = dx - meme_amount;

        uint256 dy = _k / dx;

        uint256 eth_price_without_tax = dy - _y;
        uint256 eth_tax = (eth_price_without_tax * taxRate) / precision;

        uint256 eth_price_with_tax = eth_price_without_tax + eth_tax;
        return eth_price_with_tax;
    }

    function getETHPrice(
        uint256 eth_amount
    ) public view whenNotPaused returns (uint256) {
        require(_k > 0, "Not enough liquidity");
        require(_x > 0, "Not enough MEME liquidity");

        uint256 dy = _k / _x;
        require(dy > eth_amount, "Insufficient liquidity for this ETH amount");

        dy = dy - eth_amount;

        uint256 dx = _k / dy;

        uint256 meme_price_without_tax = dx - _x;
        uint256 meme_tax = (meme_price_without_tax * taxRate) / precision;

        uint256 meme_price_with_tax = meme_price_without_tax >= meme_tax
            ? meme_price_without_tax - meme_tax
            : 0;

        return meme_price_with_tax;
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Failed to send Ether");

        emit Withdrawal(msg.sender, amount);
    }
}

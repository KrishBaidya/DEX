// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Pool.sol";

import "hardhat/console.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract DEX is Pausable, Ownable {
    using SafeERC20 for IERC20;

    Pool public immutable pool;

    event Buy(address indexed from, uint256 Meme_amount, uint256 eth_amount);
    event Sell(address indexed from, uint256 Meme_amount, uint256 eth_amount);

    mapping(address => uint256) public pendingWithdrawals;

    constructor(
        address initialOwner,
        address poolAddress
    ) Ownable(initialOwner) {
        pool = Pool(poolAddress);
    }

    receive() external payable {}

    fallback() external payable {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function buy(
        address user,
        uint256 meme_amount
    ) external payable whenNotPaused {
        require(user != address(0), "Zero Address");
        require(meme_amount > 0, "Send Some Meme");

        uint256 meme_price = pool.getMemePrice(meme_amount);
        require(meme_price <= msg.value, "Send More ETH");

        // Update pool state using getter methods
        uint256 currentK = pool.getK();
        uint256 currentX = pool.getX();

        // Perform calculations
        uint256 newX = currentX - meme_amount;
        uint256 newY = currentK / newX;

        // Update pool state
        pool.updatePoolState(newX, newY, currentK);

        emit Buy(user, meme_amount, meme_price);

        pool.meme().safeTransfer(user, meme_amount);
        pendingWithdrawals[user] += (msg.value - meme_price);
    }

    function sell(address user, uint256 eth_amount) external whenNotPaused {
        require(eth_amount > 0, "Send Some ETH");

        // Calculate the required amount of MEME to sell based on the ETH amount
        uint256 meme_price = pool.getETHPrice(eth_amount);

        // Ensure the sender has enough MEME tokens
        require(
            meme_price <= pool.meme().balanceOf(user),
            "Not enough MEME tokens"
        );

        // Ensure the sender has approved enough MEME tokens for the DEX contract to transfer
        require(
            meme_price <= pool.meme().allowance(user, address(this)),
            "Not enough MEME tokens approved"
        );

        uint256 currentK = pool.getK();
        uint256 currentY = pool.getY();

        uint256 newY = currentY - eth_amount;
        uint256 newX = currentK / newY;

        pool.updatePoolState(newX, newY, currentK);

        emit Sell(user, meme_price, eth_amount);

        pool.meme().safeTransferFrom(user, address(this), meme_price);
        pendingWithdrawals[user] += eth_amount;
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Failed to send Ether");
    }
}

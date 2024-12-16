// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "./DEX.sol";

contract ExchangeRouter is Pausable, Ownable {
    // Mapping to store token addresses mapped to their DEX addresses
    mapping(address => address payable) public tokenToDex;

    constructor(address initialOwner) Ownable(initialOwner) {}

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev Returns the DEX contract for a specific token address.
     */
    function getDex(address tokenAddress) public view returns (DEX) {
        require(
            tokenToDex[tokenAddress] != address(0x0),
            "A DEX is not available for this token!"
        );
        return DEX(tokenToDex[tokenAddress]);
    }

    /**
     * @dev Creates a new DEX for a token if one doesn't already exist.
     */
    function createDex(
        address tokenAddress,
        address poolAddress
    ) public onlyOwner {
        require(
            tokenToDex[tokenAddress] == address(0x0),
            "A DEX is already available for this token!"
        );
        tokenToDex[tokenAddress] = payable(
            address(new DEX(address(this), address(poolAddress)))
        );
    }

    /**
     * @dev Calculates the best price for buying a specific amount of tokens
     */
    function getBestBuyPrice(
        address tokenAddress,
        uint256 memeAmount
    ) public view returns (uint256) {
        return getDex(tokenAddress).pool().getMemePrice(memeAmount);
    }

    /**
     * @dev Calculates the best price for selling a specific amount of tokens
     */
    function getBestSellPrice(
        address tokenAddress,
        uint256 ethAmount
    ) public view returns (uint256) {
        return getDex(tokenAddress).pool().getETHPrice(ethAmount);
    }

    /**
     * @dev Cross-token swap via ETH intermediary
     * @param tokenA Source token address
     * @param tokenB Destination token address
     * @param amountIn Amount of tokenA to swap
     * @param minAmountOut Minimum amount of tokenB expected
     */
    function swapExactTokensForTokens(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable whenNotPaused {
        // Get DEXes for both tokens
        DEX dexA = getDex(tokenA);
        DEX dexB = getDex(tokenB);

        // Step 1: Calculate ETH value from tokenA
        uint256 ethReceived = dexA.pool().getETHPrice(amountIn);

        // Step 2: Sell tokenA for ETH
        dexA.sell(msg.sender, amountIn);

        // Step 3: Calculate tokenB amount from ETH
        uint256 tokenBAmount = dexB.pool().getMemePrice(ethReceived);

        // Ensure minimum output is met
        require(tokenBAmount >= minAmountOut, "Insufficient output amount");

        // Step 4: Buy tokenB with ETH
        dexB.buy{value: ethReceived}(msg.sender, tokenBAmount);
    }

    /**
     * @dev Pauses the given DEX contract.
     */
    function pauseDex(address payable dexAddress) public onlyOwner {
        getDex(dexAddress).pause();
    }

    /**
     * @dev Unpauses the given DEX contract.
     */
    function unpauseDex(address payable dexAddress) public onlyOwner {
        getDex(dexAddress).unpause();
    }

    /**
     * @dev Pauses the entire router contract.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the entire router contract.
     */
    function unpause() public onlyOwner {
        _unpause();
    }
}

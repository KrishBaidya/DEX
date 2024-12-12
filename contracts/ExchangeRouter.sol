// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import "./DEX.sol"; // Ensure DEX.sol is imported correctly
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

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
    function createDex(address tokenAddress, uint256 taxRate) public onlyOwner {
        require(
            tokenToDex[tokenAddress] == address(0x0),
            "A DEX is already available for this token!"
        );
        DEX newDex = new DEX(address(this), tokenAddress, taxRate);
        tokenToDex[tokenAddress] = payable(address(newDex));
    }

    /**
     * @dev Allows users to buy a specific amount of MEME tokens with ETH.
     * Calls the `buy` function in the respective DEX.
     */
    function swapEthForToken(
        address tokenAddress,
        uint256 memeAmount
    ) public payable whenNotPaused {
        DEX dex = getDex(tokenAddress);
        dex.buy{value: msg.value}(msg.sender, memeAmount);
    }

    /**
     * @dev Allows users to sell a specific amount of MEME tokens for ETH.
     * Calls the `sell` function in the respective DEX.
     */
    function swapTokenForEth(
        address tokenAddress,
        uint256 ethAmount
    ) public whenNotPaused {
        DEX dex = getDex(tokenAddress);
        dex.sell(msg.sender, ethAmount);
    }

    /**
     * @dev Allows users to swap from one token to another by selling MEME tokens of tokenA for ETH
     * and using the ETH to buy MEME tokens of tokenB.
     */
    function swapTokenAtoTokenB(
        address tokenA,
        address tokenB,
        uint256 memeAmount
    ) public payable whenNotPaused {
        DEX dexA = getDex(tokenA);
        DEX dexB = getDex(tokenB);

        // Sell tokenA (MEME) for ETH
        uint256 ethAmount = dexA.getETHPrice(memeAmount); // Get the amount of ETH for selling MEME
        console.log("ETH Amount from selling MEME:", ethAmount);

        // Sell MEME for ETH in dexA
        dexA.sell(msg.sender, memeAmount); // Corrected to pass memeAmount to sell

        // Withdraw ETH from dexA to the user
        dexA.withdraw(msg.sender); // Manually withdraw the ETH to msg.sender

        // Now msg.sender has the ETH in their wallet, send it to dexB to buy tokenB
        console.log("Sending ETH to buy MEME B:", ethAmount);

        // Approve the ETH amount to dexB
        dexB.buy{value: ethAmount}(msg.sender, memeAmount); // Use ethAmount to buy tokenB from dexB
    }

    /**
     * @dev Allows users to stack MEME and ETH in the respective DEX.
     * Calls the `stack` function in the respective DEX.
     */
    function stack(
        address tokenAddress,
        uint256 memeAmount
    ) public payable whenNotPaused {
        DEX dex = getDex(tokenAddress);
        dex.stack{value: msg.value}(memeAmount);
    }

    /**
     * @dev Allows users to unstack MEME and ETH from the respective DEX.
     * Calls the `unstack` function in the respective DEX.
     */
    function unstack(address tokenAddress, uint256 index) public whenNotPaused {
        DEX dex = getDex(tokenAddress);
        dex.unstack(index);
    }

    /**
     * @dev Pauses the given DEX contract.
     */
    function pauseDex(address payable dexAddress) public onlyOwner {
        DEX(dexAddress).pause();
    }

    /**
     * @dev Unpauses the given DEX contract.
     */
    function unpauseDex(address payable dexAddress) public onlyOwner {
        DEX(dexAddress).unpause();
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

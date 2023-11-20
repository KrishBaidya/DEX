// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "DEX.sol";

contract Router is Pausable, Ownable {
    /*@dev Get Dex address from token address
    */
    mapping(address => address payable) public token_to_Dex;

    function GetDex(address tokenAddress) public view returns(DEX) {
        require(
            token_to_Dex[tokenAddress] != address(0x0),
            "A Dex is not avaliable for this token!"
        );
        return DEX(token_to_Dex[tokenAddress]);
    }

    function CreateDex(address tokenAddress, uint256 taxRate) public {
        require(
            token_to_Dex[tokenAddress] == address(0x0),
            "A Dex is already avaliable for this token!"
        );
        DEX newDex = new DEX(tokenAddress, taxRate);
        token_to_Dex[tokenAddress] = payable(address(newDex));
    }

    function swapToken(address tokenAddress, uint256 erc20Amount) public payable {
        payable(address(GetDex(tokenAddress))).transfer(msg.value);
        GetDex(tokenAddress).buy(erc20Amount, msg.sender, msg.value);
        // payable(address(GetDex(tokenAddress))).transfer(msg.value);
    }

    function swapEth(address tokenAddress, uint256 eth_amount) public {
        GetDex(tokenAddress).sell(eth_amount, msg.sender);
    }

    function swapTokenAtoTokenB(address tokenA , address tokenB , uint256 erc20Amount) public payable  {
        DEX dexA = GetDex(tokenA);
        DEX dexB = GetDex(tokenB);

        uint256 ethAmount = dexB.getMemePrice(erc20Amount);
        payable(address(dexB)).transfer(msg.value);
        dexB.buy(erc20Amount, msg.sender, msg.value);
        dexA.sell(ethAmount, msg.sender);
    }

    function pauseDex(address payable dexAddress) public onlyOwner {
        DEX(dexAddress).pause();
    }

    function unpauseDex(address payable dexAddress) public onlyOwner {
        DEX(dexAddress).unpause();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

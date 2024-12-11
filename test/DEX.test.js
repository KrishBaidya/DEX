const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX Contract", function () {
    let DEX, dex, MEME, meme, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        DEX = await ethers.getContractFactory("DEX");
        MEME = await ethers.getContractFactory("MEME");

        meme = await MEME.deploy(owner.address);
        await meme.waitForDeployment();

        dex = await DEX.deploy(owner.address, await meme.getAddress(), 3); // 3% tax
        await dex.waitForDeployment();

        await meme.mint(addr1.address, ethers.parseEther("1000"));
        await meme.mint(addr2.address, ethers.parseEther("1000"));

        console.log("addr1 MEME Balance before approval:", ethers.formatEther(await meme.balanceOf(addr1.address)));

        await meme.connect(addr1).approve(await dex.getAddress(), ethers.parseEther("1000"));
        console.log("Allowance given to DEX:", ethers.formatEther(await meme.allowance(addr1.address, await dex.getAddress())));
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await dex.owner()).to.equal(owner.address);
        });

        it("Should have the correct initial tax rate", async function () {
            const taxRate = await dex.taxRate();
            expect(taxRate).to.equal(ethers.parseEther("0.03")); // 3%
        });
    });

    describe("Stacking", function () {
        it("Should stack MEME and ETH correctly", async function () {
            const memeAmount = ethers.parseEther("100");
            const ethAmount = ethers.parseEther("1");

            const initialMemeBalance = await meme.balanceOf(await dex.getAddress());
            const initialEthBalance = await ethers.provider.getBalance(await dex.getAddress());

            await expect(dex.connect(addr1).stack(memeAmount, { value: ethAmount }))
                .to.emit(dex, "Stack")
                .withArgs(addr1.address, memeAmount, ethAmount);

            const finalMemeBalance = await meme.balanceOf(await dex.getAddress());
            const finalEthBalance = await ethers.provider.getBalance(await dex.getAddress());

            expect(finalMemeBalance).to.equal(initialMemeBalance + memeAmount);
            expect(finalEthBalance).to.equal(initialEthBalance + ethAmount);
        });

        it("Should fail to stack if ETH or MEME is not enough", async function () {
            await expect(dex.connect(addr1).stack(ethers.parseEther("0"), { value: ethers.parseEther("1") }))
                .to.be.revertedWith("Send more MEME");

            await expect(dex.connect(addr1).stack(ethers.parseEther("100"), { value: 0 }))
                .to.be.revertedWith("Send more ETH");
        });
    });

    describe("Unstacking", function () {
        beforeEach(async function () {
            await dex.connect(addr1).stack(ethers.parseEther("100"), { value: ethers.parseEther("1") });
        });

        it("Should unstack MEME and ETH correctly", async function () {
            const memeAmount = ethers.parseEther("100");
            const ethAmount = ethers.parseEther("1");

            const beforeUnstackMemeBalance = await meme.balanceOf(addr1.address);
            const beforeUnstackEthBalance = await ethers.provider.getBalance(addr1.address);
            console.log("Before Unstack Meme Balance: " + beforeUnstackMemeBalance.toString());
            console.log("Before Unstack Eth Balance: " + beforeUnstackEthBalance.toString());

            const stack = await dex.connect(addr1).getStacks();
            console.log("Stack Details Before Unstack: ", stack);

            const stackIndex = stack.length - 1;

            const tx = await dex.connect(addr1).unstack(stackIndex);
            const receipt = await tx.wait();

            const gasUsed = BigInt(receipt.gasUsed);
            const gasPrice = BigInt(receipt.gasPrice);
            const gasCost = gasUsed * gasPrice;
            console.log("Gas Used for Unstack: " + gasUsed.toString());
            console.log("Effective Gas Price: " + gasPrice.toString());
            console.log("Gas Cost: " + gasCost.toString());

            const afterUnstackMemeBalance = await meme.balanceOf(addr1.address);
            const afterUnstackEthBalance = await ethers.provider.getBalance(addr1.address);
            console.log("After Unstack Meme Balance: " + afterUnstackMemeBalance.toString());
            console.log("After Unstack Eth Balance: " + afterUnstackEthBalance.toString());

            expect(afterUnstackMemeBalance).to.equal(beforeUnstackMemeBalance + memeAmount);
            expect(afterUnstackEthBalance).to.equal(beforeUnstackEthBalance + ethAmount -gasCost);
        });

        it("Should fail to unstack if index is out of bounds", async function () {
            await expect(dex.connect(addr1).unstack(1)).to.be.revertedWith("Index out of bounds");
        });
    });
});

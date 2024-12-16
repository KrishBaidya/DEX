const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Pool Contract", function () {
    let MEME, meme, Pool, pool, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy MEME Token
        MEME = await ethers.getContractFactory("MEME");
        meme = await MEME.deploy(owner.address);
        await meme.waitForDeployment();

        // Deploy Pool
        Pool = await ethers.getContractFactory("Pool");
        pool = await Pool.deploy(owner.address, await meme.getAddress(), 3);
        await pool.waitForDeployment();

        // Mint tokens
        await meme.mint(owner.address, ethers.parseEther("10000"));
        await meme.mint(addr1.address, ethers.parseEther("10000"));
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await pool.owner()).to.equal(owner.address);
        });

        it("Should set the correct MEME token address", async function () {
            expect(await pool.meme()).to.equal(await meme.getAddress());
        });
    });

    describe("Liquidity Management", function () {
        it("Should allow adding liquidity", async function () {
            const memeAmount = ethers.parseEther("100");
            const ethAmount = ethers.parseEther("1");

            await meme.connect(owner).approve(await pool.getAddress(), memeAmount);

            await expect(pool.connect(owner).addLiquidity(memeAmount, { value: ethAmount }))
                .to.emit(pool, "Stack")
                .withArgs(owner.address, memeAmount, ethAmount);

            let poolBalance = await pool.getStacks();
            expect(poolBalance[0].meme_amount).to.equal(memeAmount);
            expect(poolBalance[0].eth_amount).to.equal(ethAmount);
        });

        it("Should revert adding liquidity with zero amounts", async function () {
            await expect(pool.connect(owner).addLiquidity(0, { value: 0 }))
                .to.be.revertedWith("Send more MEME");
        });

        it("Should allow removing liquidity", async function () {
            const memeAmount = ethers.parseEther("100");
            const ethAmount = ethers.parseEther("1");

            // Add liquidity
            await meme.connect(owner).approve(await pool.getAddress(), memeAmount);
            await pool.connect(owner).addLiquidity(memeAmount, { value: ethAmount });

            // Remove liquidity
            await expect(pool.connect(owner).removeLiquidity(0))
                .to.emit(pool, "UnStack");

            const poolBalance = await pool.getStacks();
            expect(poolBalance.length).to.equal(0);
        });

        it("Should revert removing liquidity with invalid index", async function () {
            await expect(pool.connect(owner).removeLiquidity(0))
                .to.be.revertedWith("Invalid index");
        });
    });

    describe("Pricing Mechanisms", function () {
        beforeEach(async function () {
            const memeAmount = ethers.parseEther("1000");
            const ethAmount = ethers.parseEther("10");

            await meme.connect(owner).approve(await pool.getAddress(), memeAmount);
            await pool.connect(owner).addLiquidity(memeAmount, { value: ethAmount });
        });

        it("Should calculate MEME price correctly", async function () {
            const buyAmount = ethers.parseEther("10");
            const memePrice = await pool.getMemePrice(buyAmount);

            expect(memePrice).to.be.gt(0);
        });

        it("Should calculate ETH price correctly", async function () {
            const ethAmount = ethers.parseEther("0.1");
            const memePrice = await pool.getETHPrice(ethAmount);

            expect(memePrice).to.be.gt(0);
        });

        it("Should revert pricing with excessive amount", async function () {
            const largeAmount = ethers.parseEther("10000");

            await expect(pool.getMemePrice(largeAmount))
                .to.be.revertedWith("Insufficient liquidity for this MEME amount");

            await expect(pool.getETHPrice(largeAmount))
                .to.be.revertedWith("Insufficient liquidity for this ETH amount");
        });
    });

    describe("Stacking Functionality", function () {
        it("Should track multiple stacks", async function () {
            const memeAmount1 = ethers.parseEther("100");
            const ethAmount1 = ethers.parseEther("1");
            const memeAmount2 = ethers.parseEther("200");
            const ethAmount2 = ethers.parseEther("2");

            // First stack
            await meme.connect(owner).approve(await pool.getAddress(), memeAmount1);
            await pool.connect(owner).addLiquidity(memeAmount1, { value: ethAmount1 });

            // Second stack
            await meme.connect(owner).approve(await pool.getAddress(), memeAmount2);
            await pool.connect(owner).addLiquidity(memeAmount2, { value: ethAmount2 });

            const stacks = await pool.getStacks();
            expect(stacks.length).to.equal(2);
            expect(stacks[0].meme_amount).to.equal(memeAmount1);
            expect(stacks[1].meme_amount).to.equal(memeAmount2);
        });
    });

    describe("Pausing Mechanism", function () {
        it("Should allow owner to pause and unpause", async function () {
            await pool.connect(owner).pause();
            expect(await pool.paused()).to.be.true;

            await pool.connect(owner).unpause();
            expect(await pool.paused()).to.be.false;
        });

        it("Should prevent liquidity operations when paused", async function () {
            await pool.connect(owner).pause();

            const memeAmount = ethers.parseEther("100");
            const ethAmount = ethers.parseEther("1");

            await meme.connect(owner).approve(await pool.getAddress(), memeAmount);
            
            // Use a try-catch to log the actual revert reason
            try {
                await pool.connect(owner).addLiquidity(memeAmount, { value: ethAmount });
                expect.fail("Transaction should have been reverted");
            } catch (error) {
                // Log the full error message to see the exact revert reason
                console.log("Revert Reason:", error.message);

                // You might need to adjust this based on the actual error
                expect(error.message).to.include("EnforcedPause()");
            }
        });
    });
});
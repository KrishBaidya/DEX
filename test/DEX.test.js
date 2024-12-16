const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX Contract", function () {
    let DEX, dex, MEME, meme, Pool, pool, owner, addr1, addr2, router;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy MEME Token
        MEME = await ethers.getContractFactory("MEME");
        meme = await MEME.deploy(owner.address);
        await meme.waitForDeployment();

        // Deploy Pool
        Pool = await ethers.getContractFactory("Pool");
        pool = await Pool.deploy(owner, await meme.getAddress(), 3);
        await pool.waitForDeployment();

        // Deploy Router (if needed for routing functionality)
        const ExchangeRouter = await ethers.getContractFactory("ExchangeRouter");
        router = await ExchangeRouter.deploy(owner.address);
        await router.waitForDeployment();

        // Deploy DEX
        DEX = await ethers.getContractFactory("DEX");
        dex = await DEX.deploy(owner.address, await pool.getAddress());
        await dex.waitForDeployment();

        // Mint tokens to users
        await meme.mint(addr1.address, ethers.parseEther("1000"));
        await meme.mint(addr2.address, ethers.parseEther("1000"));
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await dex.owner()).to.equal(owner.address);
        });
    });

    describe("Pausing Functionality", function () {
        it("Should allow owner to pause and unpause", async function () {
            await dex.connect(owner).pause();
            expect(await dex.paused()).to.equal(true);

            await dex.connect(owner).unpause();
            expect(await dex.paused()).to.equal(false);
        });

        it("Should revert when trying to interact while paused", async function () {
            await dex.connect(owner).pause();
            try {
                await dex.connect(addr1).buy(await addr1.address, ethers.parseEther("1"), {
                    value: ethers.parseEther("1"),
                })
                expect.fail("Transaction should have been reverted");
            } catch (error) {
                // Log the full error message to see the exact revert reason
                console.log("Revert Reason:", error.message);

                // You might need to adjust this based on the actual error
                expect(error.message).to.include("EnforcedPause()");
            }
        });
    });


    //TODO: Need to Update Test
    // describe("Buy and Sell Functionality", function () {
    //     beforeEach(async function () {
    //         const memeAmount = ethers.parseEther("100");
    //         const ethAmount = ethers.parseEther("1");

    //         // Approve and add liquidity via pool
    //         await meme.connect(owner).approve(await pool.getAddress(), memeAmount);
    //         await pool.connect(owner).addLiquidity(memeAmount, { value: ethAmount });
    //     });

    //     it("Should allow buying MEME tokens", async function () {
    //         const buyAmount = ethers.parseEther("10");

    //         const memePrice = await pool.getMemePrice(buyAmount);
    //         const tx = await dex.connect(addr1).buy(addr1.address, buyAmount, {
    //             value: memePrice
    //         });
    //         const receipt = await tx.wait();

    //         const buyEvent = receipt.logs.find(log => log.fragment.name === "Buy");
    //         expect(buyEvent.args[0]).to.equal(addr1.address);
    //         expect(buyEvent.args[1]).to.equal(buyAmount);

    //         const addr1MemeBalance = await meme.balanceOf(addr1.address);
    //         expect(addr1MemeBalance).to.be.gte(buyAmount);

    //         const pendingWithdrawal = await dex.pendingWithdrawals(addr1.address);
    //         expect(pendingWithdrawal).to.be.gt(0);
    //     });

    //     it("Should allow selling MEME tokens", async function () {
    //         const sellAmount = ethers.parseEther("10");
    //         await dex.connect(addr1).sell(addr1.address, sellAmount, {
    //             value: ethers.parseEther("1")
    //         });

    //         await meme.connect(addr1).approve(await dex.getAddress(), sellAmount);
    //         const ethPrice = await pool.getETHPrice(sellAmount);

    //         const tx = await router.connect(addr1).swapTokenForEth(await meme.getAddress(), sellAmount);
    //         const receipt = await tx.wait();

    //         const sellEvent = receipt.logs.find(log => log.fragment.name === "Sell");
    //         expect(sellEvent.args[0]).to.equal(addr1.address);
    //         expect(sellEvent.args[1]).to.equal(sellAmount);

    //         const pendingWithdrawal = await dex.pendingWithdrawals(addr1.address);
    //         expect(pendingWithdrawal).to.be.gt(0);
    //     });
    // });
});

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ExchangeRouter", function () {
    let owner, addr1, addr2, meme, memeB, router, dex, dexB, pool, poolB;
    const taxRate = 5; // Example tax rate

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy ExchangeRouter
        const ExchangeRouter = await ethers.getContractFactory("ExchangeRouter");
        router = await ExchangeRouter.deploy(owner.address);
        await router.waitForDeployment();

        // Deploy MEME token
        const MemeToken = await ethers.getContractFactory("MEME");
        meme = await MemeToken.deploy(owner.address);
        await meme.waitForDeployment();

        // Deploy Pool for MEME token
        const PoolFactory = await ethers.getContractFactory("Pool");
        pool = await PoolFactory.deploy(await router.getAddress(), await meme.getAddress(), taxRate);
        await pool.waitForDeployment();

        // Create DEX for MEME token via the router
        await router.connect(owner).createDex(await meme.getAddress(), await pool.getAddress());

        // Get the deployed DEX
        const DexFactory = await ethers.getContractFactory("DEX");
        dex = DexFactory.attach(await router.tokenToDex(await meme.getAddress()));

        // Mint MEME tokens to addr1 for testing
        await meme.mint(addr1.address, ethers.parseEther("1000"));
    });

    describe("DEX Creation", function () {
        it("Should create a new DEX for a token", async function () {
            const dexAddress = await router.tokenToDex(await meme.getAddress());
            expect(dexAddress).to.not.equal(ethers.ZeroAddress);
        });

        it("Should revert if a DEX already exists for a token", async function () {
            // Deploy another pool
            const PoolFactory = await ethers.getContractFactory("Pool");
            const newPool = await PoolFactory.deploy(await router.getAddress(), await meme.getAddress(), taxRate);
            await newPool.waitForDeployment();

            await expect(
                router.createDex(await meme.getAddress(), await newPool.getAddress())
            ).to.be.revertedWith("A DEX is already available for this token!");
        });
    });

    describe("Price Calculation", function () {
        beforeEach(async function () {
            // Add liquidity to the pool before each test
            const memeAmount = ethers.parseEther("100");
            const ethAmount = ethers.parseEther("1");

            // Approve the pool to spend MEME tokens
            await meme.connect(addr1).approve(await pool.getAddress(), memeAmount);

            // Stake MEME and ETH into the pool
            await pool.connect(addr1).addLiquidity(memeAmount, { value: ethAmount });
        });

        it("Should calculate best buy price", async function () {
            const buyAmount = ethers.parseEther("0.01");
            const bestBuyPrice = await router.getBestBuyPrice(await meme.getAddress(), buyAmount);
            expect(bestBuyPrice).to.be.gt(0);
        });

        it("Should calculate best sell price", async function () {
            const sellAmount = ethers.parseEther("0.01");
            const bestSellPrice = await router.getBestSellPrice(await meme.getAddress(), sellAmount);
            expect(bestSellPrice).to.be.gt(0);
        });
    });


    //Todo: Need to update Test
    // describe("Token Swap", function () {
    //     beforeEach(async function () {
    //         // Deploy another token (Token B)
    //         const MemeTokenB = await ethers.getContractFactory("MEME");
    //         memeB = await MemeTokenB.deploy(addr1.address);
    //         await memeB.waitForDeployment();

    //         // Deploy Pool for Token B
    //         const PoolFactory = await ethers.getContractFactory("Pool");
    //         poolB = await PoolFactory.deploy(await router.getAddress(), await memeB.getAddress(), taxRate);
    //         await poolB.waitForDeployment();

    //         // Create DEX for Token B
    //         await router.createDex(await memeB.getAddress(), await poolB.getAddress());

    //         // Mint tokens to addr1
    //         await meme.connect(owner).mint(addr1.address, ethers.parseEther("1000"));
    //         await memeB.connect(addr1).mint(addr1.address, ethers.parseEther("1000"));

    //         // Get DEX for Token B
    //         const DexFactory = await ethers.getContractFactory("DEX");
    //         dexB = DexFactory.attach(await router.tokenToDex(await memeB.getAddress()));

    //         // Add liquidity to both pools
    //         const memeAmountA = ethers.parseEther("100");
    //         const ethAmountA = ethers.parseEther("1");

    //         const memeAmountB = ethers.parseEther("100");
    //         const ethAmountB = ethers.parseEther("1");

    //         // Approve tokens for pools
    //         await meme.connect(addr1).approve(await pool.getAddress(), memeAmountA);
    //         await memeB.connect(addr1).approve(await poolB.getAddress(), memeAmountB);

    //         // Add liquidity
    //         await pool.connect(addr1).addLiquidity(memeAmountA, { value: ethAmountA });
    //         await poolB.connect(addr1).addLiquidity(memeAmountB, { value: ethAmountB });
    //     });

    //     it("Should swap tokens via ETH intermediary", async function () {
    //         const swapAmount = ethers.parseEther("10");
    //         const minAmountOut = ethers.parseEther("9"); // Allow for some slippage

    //         // Approve tokens for router
    //         await meme.connect(addr1).approve(await router.getAddress(), swapAmount);

    //         // Perform swap
    //         await router.connect(addr1).swapExactTokensForTokens(
    //             await meme.getAddress(),
    //             await memeB.getAddress(),
    //             swapAmount,
    //             minAmountOut
    //         );

    //         // Check recipient's token B balance
    //         const addr1MemeBBalance = await memeB.balanceOf(addr1.address);
    //         expect(addr1MemeBBalance).to.be.gte(minAmountOut);
    //     });
    // });

    describe("Pausing Functions", function () {
        it("Should allow owner to pause and unpause the router", async function () {
            await router.pause();
            expect(await router.paused()).to.equal(true);

            await router.unpause();
            expect(await router.paused()).to.equal(false);
        });


        //Todo: Need to Update Test
        // it("Should allow owner to pause and unpause a DEX", async function () {
        //     const dexAddress = await router.tokenToDex(await meme.getAddress());
        //     const DexFactory = await ethers.getContractFactory("DEX");

        //     await router.pauseDex(dexAddress);
        //     const pausedDex = DexFactory.attach(dexAddress);
        //     expect(await pausedDex.paused()).to.equal(true);

        //     await router.unpauseDex(dexAddress);
        //     expect(await pausedDex.paused()).to.equal(false);
        // });

        it("Should revert token swap when router is paused", async function () {
            const swapAmount = ethers.parseEther("10");
            const minAmountOut = ethers.parseEther("9");

            // Pause the router
            await router.connect(owner).pause();

            const MemeToken = await ethers.getContractFactory("MEME");
            const memeB = await MemeToken.deploy(owner.address);
            await memeB.waitForDeployment();

            // Approve tokens for router
            await meme.connect(addr1).approve(await router.getAddress(), swapAmount);
            await memeB.connect(addr1).approve(await router.getAddress(), swapAmount);

    
            console.log(await meme.getAddress());
            console.log(await memeB.getAddress());
            // Attempt swap should revert
            try {
                await router.connect(addr1).swapExactTokensForTokens(
                    await meme.getAddress(),
                    await memeB.getAddress(),
                    swapAmount,
                    minAmountOut
                );

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

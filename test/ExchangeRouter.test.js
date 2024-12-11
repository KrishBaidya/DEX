const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ExchangeRouter", function () {
    let owner, addr1, addr2, meme, router, dex, dexB;
    const taxRate = 5; // Example tax rate

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy MEME token
        const MemeToken = await ethers.getContractFactory("MEME");
        meme = await MemeToken.deploy(owner.address);
        await meme.waitForDeployment();

        // Deploy ExchangeRouter
        const ExchangeRouter = await ethers.getContractFactory("ExchangeRouter");
        router = await ExchangeRouter.deploy(owner.address);
        await router.waitForDeployment();

        // Create DEX for MEME token via the router
        await router.connect(owner).createDex(await meme.getAddress(), taxRate);
        const DexFactory = await ethers.getContractFactory("DEX");
        dex = DexFactory.attach(await router.getDex(await meme.getAddress()));

        // Mint MEME tokens to addr1 for testing
        await meme.mint(addr1.address, ethers.parseEther("1000"));
    });

    describe("DEX Creation", function () {
        it("Should create a new DEX for a token", async function () {
            const dexAddress = await router.tokenToDex(await meme.getAddress());
            expect(dexAddress).to.not.equal(ethers.ZeroAddress);
        });

        it("Should revert if a DEX already exists for a token", async function () {
            await expect(router.createDex(await meme.getAddress(), taxRate)).to.be.revertedWith("A DEX is already available for this token!");
        });
    });

    describe("Swap Functions", function () {
        beforeEach(async function () {
            // Add liquidity to the DEX before each test
            const memeAmount = ethers.parseEther("100"); // Adjust according to your tests
            const ethAmount = ethers.parseEther("1"); // Adjust according to your tests

            // Approve the DEX to spend MEME tokens on behalf of addr1
            await meme.connect(addr1).approve(await dex.getAddress(), memeAmount);

            // Stack MEME and ETH into the DEX (add liquidity)
            await dex.connect(addr1).stack(memeAmount, { value: ethAmount });
        });

        it("Should allow buying MEME tokens with ETH", async function () {
            const buyAmount = ethers.parseEther("0.01");

            await router.connect(addr1).swapEthForToken(await meme.getAddress(), buyAmount, {
                value: ethers.parseEther("1"), // Sending 1 ETH for the swap
            });

            const addr1MemeBalance = await meme.balanceOf(addr1.address);
            expect(addr1MemeBalance).to.be.gte(buyAmount); // addr1 receives MEME tokens
        });

        it("Should allow selling MEME tokens for ETH", async function () {
            const sellAmount = ethers.parseEther("0.5");

            // Approve a sufficient amount of MEME tokens for the DEX to transfer
            const ethPrice = await dex.getETHPrice(sellAmount);
            await meme.connect(addr1).approve(await dex.getAddress(), ethPrice);

            const addr1InitialEthBalance = await ethers.provider.getBalance(addr1.address);

            const tx = await router.connect(addr1).swapTokenForEth(await meme.getAddress(), sellAmount);

            const receipt = await tx.wait();
            const gasUsed = BigInt(receipt.gasUsed);
            const gasPrice = BigInt(receipt.gasPrice);
            const gasCost = gasUsed * gasPrice;

            const addr1EthBalance = await ethers.provider.getBalance(addr1.address);
            expect(addr1EthBalance).to.be.gte(addr1InitialEthBalance - gasCost); // addr1 should have more ETH
        });
        
        it("Should allow swapping from one token (Token A) to another token (Token B)", async function () {
            // Deploy another token (Token B) and DEX for it
            const MemeTokenB = await ethers.getContractFactory("MEME");
            const memeB = await MemeTokenB.deploy(addr1.address);
            await memeB.waitForDeployment();
            await router.createDex(await memeB.getAddress(), taxRate);
        
            const DexFactory = await ethers.getContractFactory("DEX");
            dex = DexFactory.attach(await router.getDex(await meme.getAddress()));
            dexB = DexFactory.attach(await router.getDex(await memeB.getAddress()));
        
            // Mint MEME tokens to addr1
            await memeB.connect(addr1).mint(addr1.address, ethers.parseEther("1000"));
        
            // Add liquidity to both dex and dexB
            const liquidityMemeA = ethers.parseEther("100"); // For Token A (MEME)
            const liquidityEthA = ethers.parseEther("10");
        
            const liquidityMemeB = ethers.parseEther("100"); // For Token B (MEME B)
            const liquidityEthB = ethers.parseEther("10");
        
            // Approve and add liquidity to DEX A
            await meme.connect(addr1).approve(await dex.getAddress(), liquidityMemeA);
            await dex.connect(addr1).stack(liquidityMemeA, { value: liquidityEthA });
        
            // Approve and add liquidity to DEX B
            await memeB.connect(addr1).approve(await dexB.getAddress(), liquidityMemeB);
            await dexB.connect(addr1).stack(liquidityMemeB, { value: liquidityEthB });
        
            // Get available liquidity for MEME B (Token B) in DEX B
            const dexBMemeBBalance = await memeB.balanceOf(dexB.getAddress());
        
            // Determine a safe swap amount based on the available liquidity in DEX B
            const swapAmount = ethers.parseEther("5"); // Try swapping 5 tokens
            const swapableAmount = dexBMemeBBalance >= swapAmount ? swapAmount : dexBMemeBBalance;
        
            console.log("Swapping amount:", ethers.formatEther(swapableAmount));  // Log the swapable amount
        
            // Approve Token A (meme) for the swapableAmount
            await meme.connect(addr1).approve(await dex.getAddress(), swapableAmount * 20000n);
            await memeB.connect(addr1).approve(await dexB.getAddress(), swapableAmount * 20000n);
        
            // Swap Token A (MEME) to Token B (MEME B) based on available liquidity
            await router.connect(addr1).swapTokenAtoTokenB(await meme.getAddress(), await memeB.getAddress(), swapableAmount);
        
            // Validate balances after the swap
            const addr1MemeBBalance = await memeB.balanceOf(addr1.address);
            expect(addr1MemeBBalance).to.be.gte(swapableAmount); // addr1 receives Token B (MEME B)
        });
        
    });

    describe("Pausing Functions", function () {
        it("Should allow owner to pause and unpause the router", async function () {
            await router.pause();
            expect(await router.paused()).to.equal(true);

            await router.unpause();
            expect(await router.paused()).to.equal(false);
        });

        it("Should allow owner to pause and unpause a DEX", async function () {
            await router.pauseDex(await dex.getAddress());
            expect(await dex.paused()).to.equal(true);

            await router.unpauseDex(await dex.getAddress());
            expect(await dex.paused()).to.equal(false);
        });

        it("Should revert swap actions when router is paused", async function () {
            await router.connect(owner).pause();

            await expect(await router.connect(addr1).swapEthForToken(await meme.getAddress(), ethers.parseEther("1"), {
                value: ethers.parseEther("1"),
            })).to.be.revertedWith("EnforcedPause()");
        });

        it("Should revert swap actions when DEX is paused", async function () {
            await router.pauseDex(await dex.getAddress());

            await expect(router.connect(addr1).swapEthForToken(await meme.getAddress(), ethers.parseEther("1"), {
                value: ethers.parseEther("1"),
            })).to.be.revertedWith("EnforcedPause()");
        });
    });
});

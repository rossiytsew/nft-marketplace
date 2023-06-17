const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Nft Marketplace Unit Tests", () => {
        let nftMarketplace, basicNft, deployer, player
        const PRICE = ethers.utils.parseEther("0.1")
        const TOKEN_ID = 0
        beforeEach(async () => {
            const accounts = await ethers.getSigners()
            deployer = (await getNamedAccounts()).deployer
            player = accounts[1]
            await deployments.fixture(["all"])
            nftMarketplace = await ethers.getContract("NftMarketplace")
            basicNft = await ethers.getContract("BasicNft")
            await basicNft.mintNft()
            await basicNft.approve(nftMarketplace.address, TOKEN_ID)
        })

        it("lists and can be bought", async () => {
            await nftMarketplace.listItem(basicNft.address, TOKEN_ID, PRICE)
            const playerConnectedNftMarketplace = nftMarketplace.connect(player)
            await playerConnectedNftMarketplace.buyItem(basicNft.address, TOKEN_ID, {
                value: PRICE,
            })
            const newOwner = await basicNft.ownerOf(TOKEN_ID)
            const deployerProceeds = await nftMarketplace.getProceeds(deployer)
            assert.equal(newOwner.toString(), player.address)
            assert.equal(deployerProceeds.toString(), PRICE.toString())
        })
    })
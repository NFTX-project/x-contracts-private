const { expect } = require("chai");
const { BigNumber, ethers } = require("ethers");
const { check } = require("yargs");
const { expectRevert } = require("../utils/expectRevert");

const BASE = BigNumber.from(10).pow(18);
const zeroAddress = "0x0000000000000000000000000000000000000000";
const PRICE = "1000000000000000";
describe("PunkVault", function () {
  this.timeout(0);
  it("Should run as expected", async function () {
    const checkBalances = async (alwaysPrint = false) => {
      let ownerBal = await punkToken.balanceOf(owner._address);
      let aliceBal = await punkToken.balanceOf(alice._address);
      let bobBal = await punkToken.balanceOf(bob._address);
      let carolBal = await punkToken.balanceOf(carol._address);
      let vaultBal = await punkToken.balanceOf(punkVault.address);
      let supply = await punkToken.totalSupply();
      let vaultNFTBal = await cpm.balanceOf(punkVault.address);

      const isCorrect =
        vaultBal.toString() === "0" &&
        ownerBal.add(aliceBal).add(bobBal).add(carolBal).toString() ===
          supply.toString() &&
        supply.div(BASE).toString() === vaultNFTBal.toString();

      if (!isCorrect) {
        console.log("\n-------------- ERROR -------------- \n");
      }
      if (alwaysPrint || !isCorrect) {
        console.log("ERC20 \n");
        console.log("  ", ownerBal.toString(), ": initialOwner");
        console.log("  ", aliceBal.toString(), ": alice");
        console.log("  ", bobBal.toString(), ": bob");
        console.log("  ", carolBal.toString(), ": carol");
        console.log("  ", vaultBal.toString(), ": punkVault \n");
        console.log("  ", supply.toString(), ": totalSupply\n");
        console.log("ERC721 \n");
        console.log("  ", vaultNFTBal.toString(), ": punkVault \n");
        return false;
      }
      return true;
    };

    ///////////////////
    // Initialize... //
    ///////////////////

    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const PunkToken = await ethers.getContractFactory("PunkToken");
    const PunkVault = await ethers.getContractFactory("PunkVault");
    const Aggregator = await ethers.getContractFactory('PunkAggregator');

    const cpm = await Cpm.deploy();
    await cpm.deployed();

    const punkToken = await PunkToken.deploy("PunkToken", "PUNK");
    await punkToken.deployed();

    const punkVault = await PunkVault.deploy(punkToken.address, cpm.address);
    await punkVault.deployed();

    const aggregator = await Aggregator.deploy(cpm.address, punkVault.address);
    await aggregator.deployed();

    const [owner, alice, bob, carol] = await ethers.getSigners();

    await punkToken.connect(owner).transferOwnership(punkVault.address);

    const initialBalance = await punkToken.balanceOf(owner._address);
    await punkToken
      .connect(owner)
      .transfer(punkVault.address, initialBalance);

    await punkVault.connect(owner).initiateUnlock(2);
    console.log("");
    console.log("unlocking...");
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    await punkVault.connect(owner).setSupplierBounty([0, 0]);
    await punkVault.connect(owner).lock(2);

    /////////////////////////////////////
    /////////////////////////////////////

    const offerForSale = async (
      signer,
      tokenId,
      tokenAlreadyExists = false
    ) => {
      if (!tokenAlreadyExists) {
        await cpm.connect(signer).setInitialOwner(signer._address, tokenId);
      }
      await cpm.connect(signer).offerPunkForSale(tokenId, PRICE);
    };

    await offerForSale(alice, 0);
    await aggregator.connect(bob).buy(0, {value: PRICE}
    
    console.log("-- DONE --");
  });
});

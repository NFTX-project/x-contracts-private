const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { check } = require("yargs");
const { expectRevert } = require("../utils/expectRevert");

const BASE = BigNumber.from(10).pow(18);
const zeroAddress = "0x0000000000000000000000000000000000000000";
const PRICE = BASE.div(1000);
describe("XVault", function () {
  this.timeout(0);
  it("Should run as expected", async function () {
    const checkBalances = async (alwaysPrint = false) => {
      let ownerBal = await xToken.balanceOf(initialOwner._address);
      let aliceBal = await xToken.balanceOf(alice._address);
      let bobBal = await xToken.balanceOf(bob._address);
      let carolBal = await xToken.balanceOf(carol._address);
      let vaultBal = await xToken.balanceOf(xVault.address);
      let supply = await xToken.totalSupply();
      let vaultNFTBal = await cpm.balanceOf(xVault.address);

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
        console.log("  ", vaultBal.toString(), ": xVault \n");
        console.log("  ", supply.toString(), ": totalSupply\n");
        console.log("ERC721 \n");
        console.log("  ", vaultNFTBal.toString(), ": xVault \n");
        return false;
      }
      return true;
    };

    ///////////////////
    // Initialize... //
    ///////////////////

    const Cpm = await ethers.getContractFactory("CryptoXsMarket");
    const XToken = await ethers.getContractFactory("XToken");
    const XVault = await ethers.getContractFactory("XVault");
    const LarvaLabs = await ethers.getContractFactory("LinkLarvaLabs");

    const cpm = await Cpm.deploy();
    await cpm.deployed();

    const xToken = await XToken.deploy("XToken", "PUNK");
    await xToken.deployed();

    const xVault = await XVault.deploy(xToken.address, cpm.address);
    await xVault.deployed();

    const larvaLabs = await LarvaLabs.deploy(
      cpm.address,
      xToken.address,
      xVault.address
    );
    await larvaLabs.deployed();

    const [owner, alice, bob, carol] = await ethers.getSigners();

    await xToken.connect(owner).transferOwnership(xVault.address);

    const initialBalance = await xToken.balanceOf(owner._address);
    await xToken.connect(owner).transfer(xVault.address, initialBalance);

    await xVault.connect(owner).initiateUnlock(2);
    console.log("");
    console.log("unlocking...");
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    await xVault.connect(owner).setSupplierBounty([0, 0]);
    await xVault.connect(owner).lock(2);

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
      await cpm.connect(signer).offerXForSale(tokenId, PRICE);
    };

    await offerForSale(alice, 0);

    await larvaLabs.connect(bob).buy(0, { value: PRICE });

    console.log("-- DONE --");
  });
});

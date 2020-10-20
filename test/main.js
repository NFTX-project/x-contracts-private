const { expect } = require("chai");
const { BigNumber, ethers } = require("ethers");
const { check } = require("yargs");
const { expectRevert } = require("../utils/expectRevert");

const zombieIds = require("../data/x-zombie");

const BASE = BigNumber.from(10).pow(18);
const zeroAddress = "0x0000000000000000000000000000000000000000";
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

    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const XController = await ethers.getContractFactory("XController");
    const XUtils = await ethers.getContractFactory("XUtils");
    const Nftx = await ethers.getContractFactory("NFTX");

    const eligibleContract = await Eligible.deploy();
    const randomizableContract = await Randomizable.deploy();
    const controllableContract = await Controllable.deploy();
    const profitableContract = await Profitable.deploy();
    const cpm = await Cpm.deploy();
    const xToken = await XToken.deploy("XToken", "PUNK");

    await eligibleContract.deployed();
    await randomizableContract.deployed();
    await controllableContract.deployed();
    await profitableContract.deployed();
    await cpm.deployed();
    await xToken.deployed();

    const XVault = await ethers.getContractFactory("XVault");
    const xVault = await XVault.deploy(
      xToken.address,
      cpm.address,
      eligibleContract.address,
      randomizableContract.address,
      controllableContract.address,
      profitableContract.address
    );
    await xVault.deployed();

    const VaultController = await ethers.getContractFactory("VaultController");
    const vaultController = await VaultController.deploy(
      xVault.address,
      eligibleContract.address,
      controllableContract.address,
      profitableContract.address
    );
    await vaultController.deployed();

    const [initialOwner, alice, bob, carol] = await ethers.getSigners();

    await xToken.connect(initialOwner).transferOwnership(xVault.address);
    await eligibleContract
      .connect(initialOwner)
      .transferOwnership(vaultController.address);
    await controllableContract
      .connect(initialOwner)
      .transferOwnership(vaultController.address);
    await profitableContract
      .connect(initialOwner)
      .transferOwnership(vaultController.address);
    await xVault
      .connect(initialOwner)
      .transferOwnership(vaultController.address);

    /* const initialBalance = await xToken.balanceOf(initialOwner._address);
    await xToken
      .connect(initialOwner)
      .transfer(xVault.address, initialBalance); */

    await vaultController.connect(initialOwner).initiateUnlock(2);
    console.log("");
    console.log("unlocking...");
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    await vaultController.connect(initialOwner).setSupplierBounty([0, 0]);
    await vaultController
      .connect(initialOwner)
      .setEligibilities(zombieIds(), true);
    await vaultController.connect(initialOwner).lock(2);

    /////////////////////////////////////
    // XVault: *.mintX *.redeemX //
    /////////////////////////////////////

    const approveAndMint = async (
      signer,
      tokenId,
      value = 0,
      tokenAlreadyExists = false
    ) => {
      if (!tokenAlreadyExists) {
        await cpm.connect(signer).setInitialOwner(signer._address, tokenId);
      }
      await cpm
        .connect(signer)
        .offerXForSaleToAddress(tokenId, 0, xVault.address);
      await xVault.connect(signer).mintX(tokenId, { value: value });
    };

    const approveAndRedeem = async (signer, value = 0) => {
      await xToken.connect(signer).approve(xVault.address, BASE);
      await xVault.connect(signer).redeemX({ value: value });
    };

    for (let _i = 0; _i < 10; _i++) {
      const i = zombieIds()[_i];
      await approveAndMint(alice, i);
      const i2 = zombieIds()[_i + 10];
      await approveAndMint(bob, i2);
    }

    for (let _i = 0; _i < 10; _i++) {
      await approveAndRedeem(alice);
      await approveAndRedeem(bob);
    }

    const getUserHoldings = async (address, tokenSupply) => {
      let list = [];
      for (let _i = 0; _i < tokenSupply; _i++) {
        const i = zombieIds()[_i];
        const nftOwner = await cpm.xIndexToAddress(i);
        if (nftOwner === address) {
          list.push(i);
        }
      }
      return list;
    };
    let aliceNFTs = await getUserHoldings(alice._address, 20);
    let bobNFTs = await getUserHoldings(bob._address, 20);

    console.log();
    console.log(aliceNFTs);
    console.log(bobNFTs);
    console.log();
    console.log("✓ XVault: mintX, redeemX");
    console.log();

    await checkBalances();

    /////////////////////////////
    // XVault: *.mintAndRedeem //
    /////////////////////////////

    await expectRevert(xVault.connect(alice).mintAndRedeem(bobNFTs[0]));
    await expectRevert(xVault.connect(alice).mintAndRedeem(aliceNFTs[0]));
    await cpm
      .connect(alice)
      .offerXForSaleToAddress(aliceNFTs[0], 0, xVault.address);
    await xVault.connect(alice).mintAndRedeem(aliceNFTs[0]);
    expect(await cpm.xIndexToAddress(aliceNFTs[0])).to.equal(alice._address);
    await cpm
      .connect(bob)
      .offerXForSaleToAddress(bobNFTs[0], 0, xVault.address);
    await cpm
      .connect(bob)
      .offerXForSaleToAddress(bobNFTs[1], 0, xVault.address);

    await xVault.connect(bob).mintX(bobNFTs[0]);
    await xVault.connect(bob).mintX(bobNFTs[1]);
    await cpm
      .connect(alice)
      .offerXForSaleToAddress(aliceNFTs[0], 0, xVault.address);
    await xVault.connect(alice).mintAndRedeem(aliceNFTs[0]);
    const selections = [];
    for (let i = 0; i < 10; i++) {
      const newSelection =
        (await cpm.xIndexToAddress(bobNFTs[0])) == alice._address
          ? bobNFTs[0]
          : (await cpm.xIndexToAddress(bobNFTs[1])) == alice._address
          ? bobNFTs[1]
          : aliceNFTs[0];
      selections.push(newSelection);
      await cpm
        .connect(alice)
        .offerXForSaleToAddress(newSelection, 0, xVault.address);
      await xVault.connect(alice).mintAndRedeem(newSelection);
    }
    await xToken.connect(bob).approve(xVault.address, BASE.mul(2).toString());
    await xVault.connect(bob).redeemX();
    await xVault.connect(bob).redeemX();
    console.log(selections);
    console.log();
    console.log("✓ XVault: mintAndRedeem");

    await checkBalances();

    const setApprovalForAll = async (signer, address, tokenIds) => {
      for (let i = 0; i < tokenIds.length; i++) {
        const tokenId = tokenIds[i];
        await cpm.connect(signer).offerXForSaleToAddress(tokenId, 0, address);
      }
    };

    //////////////////////////////////////////////////////
    // XVault: *.mintXMultiple, *.redeemXMultiple //
    //////////////////////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await setApprovalForAll(alice, xVault.address, aliceNFTs);
    await setApprovalForAll(bob, xVault.address, bobNFTs);
    await xVault.connect(alice).mintXMultiple(aliceNFTs.slice(0, 5));
    for (let i = 0; i < 5; i++) {
      expect(await cpm.xIndexToAddress(aliceNFTs[i])).to.equal(xVault.address);
    }
    for (let i = 5; i < 10; i++) {
      expect(await cpm.xIndexToAddress(aliceNFTs[i])).to.equal(alice._address);
    }
    const FIVE = BASE.mul(5).toString();
    expect((await xToken.balanceOf(alice._address)).toString()).to.equal(FIVE);
    await xToken.connect(alice).approve(xVault.address, FIVE);
    await xVault.connect(alice).redeemXMultiple(5);
    for (let i = 0; i < 10; i++) {
      expect(await cpm.xIndexToAddress(aliceNFTs[i])).to.equal(alice._address);
    }
    expect((await xToken.balanceOf(alice._address)).toString()).to.equal("0");

    console.log();
    console.log("✓ XVault: mintXMultiple, redeemXMultiple");
    console.log();

    await checkBalances();

    /////////////////////////////////////
    // XVault: *.mintAndRedeemMultiple //
    /////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await xVault.connect(bob).mintXMultiple(bobNFTs);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await setApprovalForAll(alice, xVault.address, aliceNFTs);
    await xVault.connect(alice).mintAndRedeemMultiple(aliceNFTs);
    let _aliceNFTs = await getUserHoldings(alice._address, 20);
    let list = [];
    for (let i = 0; i < 10; i++) {
      const item = _aliceNFTs[i];
      list.push(aliceNFTs.includes(item) ? 0 : 1);
    }
    console.log(list);
    await xToken.connect(bob).approve(xVault.address, BASE.mul(10).toString());
    await xVault.connect(bob).redeemXMultiple(10);

    console.log();
    console.log("✓ XVault: mintAndRedeemMultiple");

    await checkBalances();

    ////////////////
    // Manageable //
    ////////////////

    await vaultController
      .connect(initialOwner)
      .transferOwnership(carol._address);
    await expectRevert(
      vaultController.connect(carol).migrate(carol._address, 100)
    );
    await vaultController.connect(carol).initiateUnlock(0);
    await vaultController.connect(carol).initiateUnlock(1);
    await expectRevert(vaultController.connect(carol).changeTokenName("Name"));
    await expectRevert(
      vaultController.connect(carol).changeTokenSymbol("NAME")
    );
    await vaultController.connect(carol).initiateUnlock(2);
    await expectRevert(
      vaultController.connect(carol).migrate(carol._address, 100)
    );
    await checkBalances();
    await vaultController.connect(carol).lock(0);
    await vaultController.connect(carol).lock(1);
    await vaultController.connect(carol).lock(2);

    await checkBalances();
    console.log();
    console.log("✓ Manageable");
    console.log();

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    ////////////////////
    // Timelock.Short //
    ////////////////////

    await expectRevert(
      vaultController
        .connect(carol)
        .mintRetroactively(aliceNFTs[0], alice._address)
    );
    await cpm.connect(alice).transferX(xVault.address, aliceNFTs[0]);
    ////////////////////////////////////////////////////////////////////////
    await vaultController.connect(carol).initiateUnlock(0);
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////
    await expectRevert(xVault.connect(alice).mintX(aliceNFTs[0]));
    await expectRevert(
      vaultController
        .connect(carol)
        .mintRetroactively(bobNFTs[0], alice._address)
    );
    await vaultController
      .connect(carol)
      .mintRetroactively(aliceNFTs[0], alice._address);
    await xToken.connect(alice).transfer(xVault.address, BASE.div(2));
    await expectRevert(
      vaultController.connect(carol).redeemRetroactively(alice._address)
    );
    await xToken.connect(alice).transfer(xVault.address, BASE.div(2));
    await vaultController.connect(carol).redeemRetroactively(alice._address);
    ////////////////////////////////////////////////////////////////////////
    await vaultController.connect(carol).lock(0);

    console.log("✓ Timelock.Short");
    console.log();

    /////////////////////
    // Timelock.Medium //
    /////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    await checkBalances();
    await expectRevert(vaultController.connect(carol).changeTokenName("Name"));
    await expectRevert(
      vaultController.connect(carol).changeTokenSymbol("NAME")
    );
    await expectRevert(
      vaultController.connect(carol).setFeesArray(0, [1, 1, 1])
    );
    await expectRevert(
      vaultController.connect(carol).setFeesArray(1, [1, 1, 1])
    );
    await expectRevert(
      vaultController.connect(carol).setFeesArray(2, [1, 1, 1])
    );
    ////////////////////////////////////////////////////////////////////////
    await vaultController.connect(carol).initiateUnlock(1);
    await vaultController.connect(carol).initiateUnlock(2); // because setFeesArray
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////

    // Manageable: *.changeTokenName, *.changeTokenSymbol

    await expectRevert(vaultController.connect(alice).changeTokenName("Name"));
    await expectRevert(
      vaultController.connect(alice).changeTokenSymbol("NAME")
    );
    await vaultController.connect(carol).changeTokenName("Name");
    await vaultController.connect(carol).changeTokenSymbol("NAME");
    expect(await xToken.name()).to.equal("Name");
    expect(await xToken.symbol()).to.equal("NAME");
    await checkBalances();

    console.log("✓ Manageable: changeTokenName, changeTokenSymbol");
    console.log();
    //
    // Profitable: *.setMintFees
    await setApprovalForAll(alice, xVault.address, aliceNFTs.slice(0, 5));

    await vaultController.connect(carol).setFeesArray(0, [2, 2, 2]);
    await expectRevert(xVault.connect(alice).mintX(aliceNFTs[0], { value: 1 }));
    await xVault.connect(alice).mintX(aliceNFTs[0], { value: 2 });
    await expectRevert(
      xVault.connect(alice).mintXMultiple(aliceNFTs.slice(2, 5), { value: 7 })
    );
    await xVault
      .connect(alice)
      .mintXMultiple(aliceNFTs.slice(2, 5), { value: 8 });
    await checkBalances();

    console.log("✓ Profitable: setMintFees");
    console.log();

    // Profitable: *.setDualFees
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, xVault.address, aliceNFTs.slice(0, 5));
    await vaultController.connect(carol).setFeesArray(2, [2, 2, 2]);
    await expectRevert(
      xVault.connect(alice).mintAndRedeem(aliceNFTs[1], { value: 1 })
    );
    await xVault.connect(alice).mintAndRedeem(aliceNFTs[1], { value: 2 });

    await expectRevert(
      xVault
        .connect(alice)
        .mintAndRedeemMultiple(aliceNFTs.slice(2, 5), { value: 7 })
    );

    await xVault
      .connect(alice)
      .mintAndRedeemMultiple(aliceNFTs.slice(2, 5), { value: 8 });
    ////////////////////////////////////////////////////////////////////////
    await checkBalances();
    console.log("✓ Profitable: setDualFees");
    console.log();

    // Profitable: *.setIntegrator, *.isIntegrator, *getNumIntegrators
    aliceNFTs = await getUserHoldings(alice._address, 20);

    await expectRevert(
      vaultController.connect(alice).setIntegrator(alice._address, true)
    );
    await cpm
      .connect(alice)
      .offerXForSaleToAddress(aliceNFTs[0], 0, xVault.address);
    await expectRevert(xVault.connect(alice).mintX(aliceNFTs[0]));
    expect((await profitableContract.getNumIntegrators()).toString()).to.equal(
      "0"
    );
    expect(await profitableContract.isIntegrator(alice._address)).to.equal(
      false
    );
    await vaultController.connect(carol).setIntegrator(alice._address, true);
    expect((await profitableContract.getNumIntegrators()).toString()).to.equal(
      "1"
    );
    expect(await profitableContract.isIntegrator(alice._address)).to.equal(
      true
    );
    await xVault.connect(alice).mintX(aliceNFTs[0]);

    await xToken.connect(alice).approve(xVault.address, BASE.mul(4).toString());
    await xVault.connect(alice).redeemXMultiple(4);
    await vaultController.connect(carol).setIntegrator(alice._address, false);
    expect((await profitableContract.getNumIntegrators()).toString()).to.equal(
      "0"
    );
    expect(await profitableContract.isIntegrator(alice._address)).to.equal(
      false
    );
    await vaultController.connect(carol).setFeesArray(0, [0, 0, 0]);
    await vaultController.connect(carol).setFeesArray(2, [0, 0, 0]);

    ///////////////////////////////////////////////////
    // Controllable: *.setController, *.directRedeem //
    ///////////////////////////////////////////////////
    await checkBalances();
    let vaultNFTs = await getUserHoldings(xVault.address, 20);

    await expectRevert(
      vaultController.connect(alice).setController(alice._address, true)
    );
    await expectRevert(
      vaultController.connect(bob).setController(alice._address, true)
    );
    await xToken.connect(alice).approve(xVault.address, BASE);
    await expectRevert(
      xVault.connect(alice).directRedeem(vaultNFTs[0], alice._address)
    );
    await expectRevert(
      xVault.connect(alice).directRedeem(vaultNFTs[0], bob._address)
    );
    await vaultController.connect(carol).setController(alice._address, true);
    await xVault.connect(alice).directRedeem(vaultNFTs[0], alice._address);
    expect(await cpm.xIndexToAddress(vaultNFTs[0])).to.equal(alice._address);

    console.log("✓ Controllable");

    await vaultController.connect(carol).setController(alice._address, false);
    await setApprovalForAll(alice, xVault.address, vaultNFTs.slice(0, 1));
    await xVault.connect(alice).mintX(vaultNFTs[0]);
    await vaultController.connect(carol).lock(1);
    await vaultController.connect(carol).lock(2); // because setFeesArray
    await checkBalances();
    console.log();
    console.log("✓ Timelock.Medium");
    console.log();

    ///////////////////
    // Timelock.Long //
    ///////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    await expectRevert(
      vaultController.connect(carol).migrate(bob._address, 100)
    );
    ////////////////////////////////////////////////////////////////////////
    await vaultController.connect(carol).initiateUnlock(2);
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////
    await vaultController.connect(carol).setFeesArray(1, [2, 2, 2]);
    await xToken.connect(alice).approve(xVault.address, BASE);
    await expectRevert(xVault.connect(alice).redeemX({ value: 1 }));
    await xVault.connect(alice).redeemX({ value: 2 });
    await setApprovalForAll(alice, xVault.address, aliceNFTs);
    await xVault.connect(alice).mintXMultiple(aliceNFTs);
    const bobBal = parseInt((await cpm.balanceOf(bob._address)).toString());
    const vaultBal = parseInt((await cpm.balanceOf(xVault.address)).toString());
    vaultNFTs = await getUserHoldings(xVault.address, 20);
    await vaultController.connect(carol).migrate(bob._address, 7);
    expect(await xToken.owner()).to.equal(xVault.address);
    await vaultController.connect(carol).migrate(bob._address, 1);
    expect(await xToken.owner()).to.equal(xVault.address);
    await vaultController.connect(carol).migrate(bob._address, 1);
    expect(await xToken.owner()).to.equal(bob._address);

    expect((await cpm.balanceOf(bob._address)).toString()).to.equal(
      (bobBal + vaultBal).toString()
    );

    for (let i = 0; i < vaultNFTs.length; i++) {
      await cpm.connect(bob).transferX(alice._address, vaultNFTs[i]);
    }
    await xToken.connect(alice).burn(BASE.mul(9));
    await setApprovalForAll(alice, xVault.address, vaultNFTs);
    await xToken.connect(bob).transferOwnership(xVault.address);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await xVault.connect(alice).mintXMultiple(vaultNFTs);

    ////////////////////////////////////////////////////////////////////////

    bobNFTs = await getUserHoldings(bob._address, 20);
    const unit = BASE.div(100);
    await vaultController.connect(carol).setFeesArray(1, [0, 0, 0]);
    await vaultController
      .connect(carol)
      .setSupplierBounty([unit.toString(), 5]);
    await xToken.connect(alice).approve(xVault.address, BASE.mul(9));
    await xVault.connect(alice).redeemXMultiple(4);
    for (let i = 0; i < 5; i++) {
      await expectRevert(
        xVault.connect(alice).redeemX({
          value: unit
            .mul(i + 1)
            .sub(1)
            .toString(),
        })
      );
      await xVault
        .connect(alice)
        .redeemX({ value: unit.mul(i + 1).toString() });
    }
    aliceNFTs = await getUserHoldings(alice._address, 20);
    let arr = aliceNFTs.splice(0, 2);

    await setApprovalForAll(alice, xVault.address, arr);

    await xVault.connect(alice).mintXMultiple(arr);
    await xToken.connect(alice).approve(xVault.address, BASE.mul(2));
    await expectRevert(
      xVault.connect(alice).redeemXMultiple(2, {
        value: unit.mul(9).sub(1).toString(),
      })
    );
    await checkBalances();
    await xVault.connect(alice).redeemXMultiple(2, {
      value: unit.mul(9).toString(),
    });
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, xVault.address, aliceNFTs.slice(0, 2));
    let balance = await web3.eth.getBalance(xVault.address);
    await xVault.connect(alice).mintXMultiple(aliceNFTs.slice(0, 2));
    let newBalance = await web3.eth.getBalance(xVault.address);
    expect(BigNumber.from(balance).sub(newBalance).toString()).to.equal(
      unit.mul(5 + 4).toString()
    );
    await setApprovalForAll(alice, xVault.address, aliceNFTs.slice(2));
    balance = await web3.eth.getBalance(xVault.address);
    await xVault.connect(alice).mintXMultiple(aliceNFTs.slice(2));
    newBalance = await web3.eth.getBalance(xVault.address);
    expect(BigNumber.from(balance).sub(newBalance).toString()).to.equal(
      unit.mul(3 + 2 + 1).toString()
    );
    let tBal = await xToken.balanceOf(alice._address);
    await xToken.connect(alice).approve(xVault.address, tBal);
    let num = 5 + 4 + 3 + 2 + 1;
    console.log(1);
    await expectRevert(
      xVault.connect(alice).redeemXMultiple(BigNumber.from(tBal).div(BASE), {
        value: unit.mul(num).sub(1).toString(),
      })
    );
    await xVault
      .connect(alice)
      .redeemXMultiple(BigNumber.from(tBal).div(BASE), {
        value: unit.mul(num).toString(),
      });

    ////////////////////////////////////////////////////////////////////////
    await vaultController.connect(carol).setSupplierBounty([0, 0]);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, xVault.address, aliceNFTs);
    await xVault
      .connect(alice)
      .mintXMultiple(aliceNFTs.slice(0, aliceNFTs.length - 1));
    await vaultController.connect(carol).lock(2);

    console.log("✓ Profitable: setBurnFees");
    console.log();

    console.log("✓ Timelock.Long");

    ///////////////////////////////////////////////////////////////
    // Pausable: *.pause, *.unpause & XVaultSafe: *.simpleRedeem //
    ///////////////////////////////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await expectRevert(vaultController.connect(alice).pause());
    await expectRevert(vaultController.connect(alice).unpause());
    await xToken.connect(alice).approve(xVault.address, BASE);
    await expectRevert(xVault.connect(alice).simpleRedeem());
    await vaultController.connect(carol).pause();
    let aliceBal = await xToken.balanceOf(alice._address);
    balance = await xToken.balanceOf(alice._address);
    await xVault.connect(alice).simpleRedeem();
    expect((await xToken.balanceOf(alice._address)).toString()).to.equal(
      balance.sub(BASE).toString()
    );
    await checkBalances();
    console.log();
    console.log("✓ Pausable");
    console.log();

    console.log("-- DONE --\n");
  });
});

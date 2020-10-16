const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { check } = require("yargs");
const { expectRevert } = require("../utils/expectRevert");

const zombieIds = require("../data/zombies");

const BASE = BigNumber.from(10).pow(18);
const zeroAddress = "0x0000000000000000000000000000000000000000";
describe("PunkVault", function () {
  this.timeout(0);
  it("Should run as expected", async function () {
    const checkBalances = async (alwaysPrint = false) => {
      let ownerBal = await punkToken.balanceOf(initialOwner._address);
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

    const Eligible = await ethers.getContractFactory("Eligible");
    const Randomizable = await ethers.getContractFactory("Randomizable");
    const Controllable = await ethers.getContractFactory("Controllable");
    const Profitable = await ethers.getContractFactory("Profitable");
    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const PunkToken = await ethers.getContractFactory("PunkToken");

    const eligibleContract = await Eligible.deploy();
    const randomizableContract = await Randomizable.deploy();
    const controllableContract = await Controllable.deploy();
    const profitableContract = await Profitable.deploy();
    const cpm = await Cpm.deploy();
    const punkToken = await PunkToken.deploy("PunkToken", "PUNK");

    await eligibleContract.deployed();
    await randomizableContract.deployed();
    await controllableContract.deployed();
    await profitableContract.deployed();
    await cpm.deployed();
    await punkToken.deployed();

    const PunkVault = await ethers.getContractFactory("PunkVault");
    const punkVault = await PunkVault.deploy(punkToken.address, cpm.address);
    await punkVault.deployed();

    const VaultController = await ethers.getContractFactory("VaultController");
    const vaultController = await VaultController.deploy(
      punkVault.address,
      eligibleContract.address,
      controllableContract.address,
      profitableContract.address
    );
    await vaultController.deployed();

    const [initialOwner, alice, bob, carol] = await ethers.getSigners();

    await punkToken.connect(initialOwner).transferOwnership(punkVault.address);
    await eligibleContract
      .connect(initialOwner)
      .transferOwnership(vaultController.address);
    await controllableContract
      .connect(initialOwner)
      .transferOwnership(vaultController.address);
    await profitableContract
      .connect(initialOwner)
      .transferOwnership(vaultController.address);
    await punkVault
      .connect(initialOwner)
      .transferOwnership(vaultController.address);

    /* const initialBalance = await punkToken.balanceOf(initialOwner._address);
    await punkToken
      .connect(initialOwner)
      .transfer(punkVault.address, initialBalance); */

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
    // PunkVault: *.mintPunk *.redeemPunk //
    /////////////////////////////////////

    const approveAndMint = async (
      signer,
      tokenId,
      value = 0,
      tokenAlreadyExists = false
    ) => {
      console.log(999991);
      if (!tokenAlreadyExists) {
        console.log(99999);

        await cpm.connect(signer).setInitialOwner(signer._address, tokenId);
        return;
      }
      await cpm
        .connect(signer)
        .offerPunkForSaleToAddress(tokenId, 0, punkVault.address);

      await punkVault.connect(signer).mintPunk(tokenId, { value: value });
    };

    const approveAndRedeem = async (signer, value = 0) => {
      await punkToken.connect(signer).approve(punkVault.address, BASE);
      await punkVault.connect(signer).redeemPunk({ value: value });
    };

    for (let _i = 0; _i < 10; _i++) {
      const i = zombieIds()[_i];
      // return;
      await approveAndMint(alice, i);
      return;
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
        const nftOwner = await cpm.punkIndexToAddress(i);
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
    console.log("✓ PunkVault: mintPunk, redeemPunk");
    console.log();

    await checkBalances();

    /////////////////////////////
    // PunkVault: *.mintAndRedeem //
    /////////////////////////////

    await expectRevert(punkVault.connect(alice).mintAndRedeem(bobNFTs[0]));
    await expectRevert(punkVault.connect(alice).mintAndRedeem(aliceNFTs[0]));
    await cpm
      .connect(alice)
      .offerPunkForSaleToAddress(aliceNFTs[0], 0, punkVault.address);
    await punkVault.connect(alice).mintAndRedeem(aliceNFTs[0]);
    expect(await cpm.punkIndexToAddress(aliceNFTs[0])).to.equal(alice._address);
    await cpm
      .connect(bob)
      .offerPunkForSaleToAddress(bobNFTs[0], 0, punkVault.address);
    await cpm
      .connect(bob)
      .offerPunkForSaleToAddress(bobNFTs[1], 0, punkVault.address);

    await punkVault.connect(bob).mintPunk(bobNFTs[0]);
    await punkVault.connect(bob).mintPunk(bobNFTs[1]);
    await cpm
      .connect(alice)
      .offerPunkForSaleToAddress(aliceNFTs[0], 0, punkVault.address);
    await punkVault.connect(alice).mintAndRedeem(aliceNFTs[0]);
    const selections = [];
    for (let i = 0; i < 10; i++) {
      const newSelection =
        (await cpm.punkIndexToAddress(bobNFTs[0])) == alice._address
          ? bobNFTs[0]
          : (await cpm.punkIndexToAddress(bobNFTs[1])) == alice._address
          ? bobNFTs[1]
          : aliceNFTs[0];
      selections.push(newSelection);
      await cpm
        .connect(alice)
        .offerPunkForSaleToAddress(newSelection, 0, punkVault.address);
      await punkVault.connect(alice).mintAndRedeem(newSelection);
    }
    await punkToken
      .connect(bob)
      .approve(punkVault.address, BASE.mul(2).toString());
    await punkVault.connect(bob).redeemPunk();
    await punkVault.connect(bob).redeemPunk();
    console.log(selections);
    console.log();
    console.log("✓ PunkVault: mintAndRedeem");

    await checkBalances();

    const setApprovalForAll = async (signer, address, tokenIds) => {
      for (let i = 0; i < tokenIds.length; i++) {
        const tokenId = tokenIds[i];
        await cpm
          .connect(signer)
          .offerPunkForSaleToAddress(tokenId, 0, address);
      }
    };

    //////////////////////////////////////////////////////
    // PunkVault: *.mintPunkMultiple, *.redeemPunkMultiple //
    //////////////////////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await setApprovalForAll(alice, punkVault.address, aliceNFTs);
    await setApprovalForAll(bob, punkVault.address, bobNFTs);
    await punkVault.connect(initialOwner).setSafeMode(true);
    await expectRevert(
      punkVault.connect(alice).mintPunkMultiple(aliceNFTs.slice(0, 5))
    );
    await punkVault.connect(initialOwner).setSafeMode(false);
    await punkVault.connect(alice).mintPunkMultiple(aliceNFTs.slice(0, 5));
    for (let i = 0; i < 5; i++) {
      expect(await cpm.punkIndexToAddress(aliceNFTs[i])).to.equal(
        punkVault.address
      );
    }
    for (let i = 5; i < 10; i++) {
      expect(await cpm.punkIndexToAddress(aliceNFTs[i])).to.equal(
        alice._address
      );
    }
    const FIVE = BASE.mul(5).toString();
    expect((await punkToken.balanceOf(alice._address)).toString()).to.equal(
      FIVE
    );
    await punkToken.connect(alice).approve(punkVault.address, FIVE);
    await punkVault.connect(initialOwner).setSafeMode(true);
    await expectRevert(punkVault.connect(alice).redeemPunkMultiple(5));
    await punkVault.connect(initialOwner).setSafeMode(false);
    await punkVault.connect(alice).redeemPunkMultiple(5);
    for (let i = 0; i < 10; i++) {
      expect(await cpm.punkIndexToAddress(aliceNFTs[i])).to.equal(
        alice._address
      );
    }
    expect((await punkToken.balanceOf(alice._address)).toString()).to.equal(
      "0"
    );

    console.log();
    console.log("✓ PunkVault: mintPunkMultiple, redeemPunkMultiple");
    console.log();

    await checkBalances();

    /////////////////////////////////////
    // PunkVault: *.mintAndRedeemMultiple //
    /////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await punkVault.connect(bob).mintPunkMultiple(bobNFTs);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await setApprovalForAll(alice, punkVault.address, aliceNFTs);
    await punkVault.connect(alice).mintAndRedeemMultiple(aliceNFTs);
    let _aliceNFTs = await getUserHoldings(alice._address, 20);
    let list = [];
    for (let i = 0; i < 10; i++) {
      const item = _aliceNFTs[i];
      list.push(aliceNFTs.includes(item) ? 0 : 1);
    }
    console.log(list);
    await punkToken
      .connect(bob)
      .approve(punkVault.address, BASE.mul(10).toString());
    await punkVault.connect(bob).redeemPunkMultiple(10);

    console.log();
    console.log("✓ PunkVault: mintAndRedeemMultiple");

    await checkBalances();

    ////////////////
    // Manageable //
    ////////////////

    await expectRevert(
      punkVault.connect(initialOwner).migrate(initialOwner._address, 100)
    );
    await expectRevert(
      punkVault.connect(alice).transferOwnership(carol._address)
    );
    await expectRevert(
      punkVault.connect(carol).transferOwnership(carol._address)
    );
    await punkVault.connect(initialOwner).transferOwnership(carol._address);
    await expectRevert(punkVault.connect(carol).migrate(carol._address, 100));
    await punkVault.connect(carol).initiateUnlock(0);
    await punkVault.connect(carol).initiateUnlock(1);
    await expectRevert(punkVault.connect(carol).changeTokenName("Name"));
    await expectRevert(punkVault.connect(carol).changeTokenSymbol("NAME"));
    await punkVault.connect(carol).initiateUnlock(2);
    await expectRevert(punkVault.connect(carol).migrate(carol._address, 100));
    await checkBalances();
    await punkVault.connect(carol).lock(0);
    await punkVault.connect(carol).lock(1);
    await punkVault.connect(carol).lock(2);

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
      punkVault.connect(carol).mintRetroactively(aliceNFTs[0], alice._address)
    );
    await cpm.connect(alice).transferPunk(punkVault.address, aliceNFTs[0]);
    ////////////////////////////////////////////////////////////////////////
    await punkVault.connect(carol).initiateUnlock(0);
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////
    await expectRevert(punkVault.connect(alice).mintPunk(aliceNFTs[0]));
    await expectRevert(
      punkVault.connect(carol).mintRetroactively(bobNFTs[0], alice._address)
    );
    await punkVault
      .connect(carol)
      .mintRetroactively(aliceNFTs[0], alice._address);
    await punkToken.connect(alice).transfer(punkVault.address, BASE.div(2));
    await expectRevert(
      punkVault.connect(carol).redeemRetroactively(alice._address)
    );
    await punkToken.connect(alice).transfer(punkVault.address, BASE.div(2));
    await punkVault.connect(carol).redeemRetroactively(alice._address);
    ////////////////////////////////////////////////////////////////////////
    await punkVault.connect(carol).lock(0);

    console.log("✓ Timelock.Short");
    console.log();

    /////////////////////
    // Timelock.Medium //
    /////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    await checkBalances();
    await expectRevert(punkVault.connect(carol).changeTokenName("Name"));
    await expectRevert(punkVault.connect(carol).changeTokenSymbol("NAME"));
    await expectRevert(punkVault.connect(carol).setMintFees([1, 1, 1]));
    await expectRevert(punkVault.connect(carol).setBurnFees([1, 1, 1]));
    await expectRevert(punkVault.connect(carol).setDualFees([1, 1, 1]));
    ////////////////////////////////////////////////////////////////////////
    await punkVault.connect(carol).initiateUnlock(1);
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////

    // Manageable: *.changeTokenName, *.changeTokenSymbol

    await expectRevert(punkVault.connect(alice).changeTokenName("Name"));
    await expectRevert(punkVault.connect(alice).changeTokenSymbol("NAME"));
    await punkVault.connect(carol).changeTokenName("Name");
    await punkVault.connect(carol).changeTokenSymbol("NAME");
    expect(await punkToken.name()).to.equal("Name");
    expect(await punkToken.symbol()).to.equal("NAME");
    await checkBalances();

    console.log("✓ Manageable: changeTokenName, changeTokenSymbol");
    console.log();

    // Profitable: *.setMintFees
    await setApprovalForAll(alice, punkVault.address, aliceNFTs.slice(0, 5));

    await punkVault.connect(carol).setMintFees([2, 2, 2]);
    await expectRevert(
      punkVault.connect(alice).mintPunk(aliceNFTs[0], { value: 1 })
    );
    await punkVault.connect(alice).mintPunk(aliceNFTs[0], { value: 2 });
    await expectRevert(
      punkVault
        .connect(alice)
        .mintPunkMultiple(aliceNFTs.slice(2, 5), { value: 7 })
    );
    await punkVault
      .connect(alice)
      .mintPunkMultiple(aliceNFTs.slice(2, 5), { value: 8 });
    await checkBalances();

    console.log("✓ Profitable: setMintFees");
    console.log();

    // Profitable: *.setDualFees
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, punkVault.address, aliceNFTs.slice(0, 5));
    await punkVault.connect(carol).setDualFees([2, 2, 2]);
    await expectRevert(
      punkVault.connect(alice).mintAndRedeem(aliceNFTs[1], { value: 1 })
    );
    await punkVault.connect(alice).mintAndRedeem(aliceNFTs[1], { value: 2 });

    await expectRevert(
      punkVault
        .connect(alice)
        .mintAndRedeemMultiple(aliceNFTs.slice(2, 5), { value: 7 })
    );

    await punkVault
      .connect(alice)
      .mintAndRedeemMultiple(aliceNFTs.slice(2, 5), { value: 8 });
    ////////////////////////////////////////////////////////////////////////
    await checkBalances();
    console.log("✓ Profitable: setDualFees");
    console.log();

    // Profitable: *.setIntegrator, *.isIntegrator, *getNumIntegrators
    aliceNFTs = await getUserHoldings(alice._address, 20);

    await expectRevert(
      punkVault.connect(alice).setIntegrator(alice._address, true)
    );
    await cpm
      .connect(alice)
      .offerPunkForSaleToAddress(aliceNFTs[0], 0, punkVault.address);
    await expectRevert(punkVault.connect(alice).mintPunk(aliceNFTs[0]));
    expect((await punkVault.getNumIntegrators()).toString()).to.equal("0");
    expect(await punkVault.isIntegrator(alice._address)).to.equal(false);
    await punkVault.connect(carol).setIntegrator(alice._address, true);
    expect((await punkVault.getNumIntegrators()).toString()).to.equal("1");
    expect(await punkVault.isIntegrator(alice._address)).to.equal(true);
    await punkVault.connect(alice).mintPunk(aliceNFTs[0]);

    await punkToken
      .connect(alice)
      .approve(punkVault.address, BASE.mul(4).toString());
    await punkVault.connect(alice).redeemPunkMultiple(4);
    await punkVault.connect(carol).setIntegrator(alice._address, false);
    expect((await punkVault.getNumIntegrators()).toString()).to.equal("0");
    expect(await punkVault.isIntegrator(alice._address)).to.equal(false);
    await punkVault.connect(carol).setMintFees([0, 0, 0]);
    await punkVault.connect(carol).setDualFees([0, 0, 0]);

    ///////////////////////////////////////////////////
    // Controllable: *.setController, *.directRedeem //
    ///////////////////////////////////////////////////

    await checkBalances();
    let vaultNFTs = await getUserHoldings(punkVault.address, 20);

    await expectRevert(
      punkVault.connect(alice).setController(alice._address, true)
    );
    await expectRevert(
      punkVault.connect(bob).setController(alice._address, true)
    );
    await punkToken.connect(alice).approve(punkVault.address, BASE);
    await expectRevert(
      punkVault.connect(alice).directRedeem(vaultNFTs[0], alice._address)
    );
    await expectRevert(
      punkVault.connect(alice).directRedeem(vaultNFTs[0], bob._address)
    );
    await punkVault.connect(carol).setController(alice._address, true);
    await punkVault.connect(alice).directRedeem(vaultNFTs[0], alice._address);
    expect(await cpm.punkIndexToAddress(vaultNFTs[0])).to.equal(alice._address);

    console.log("✓ Controllable");

    await punkVault.connect(carol).setController(alice._address, false);
    await setApprovalForAll(alice, punkVault.address, vaultNFTs.slice(0, 1));
    await punkVault.connect(alice).mintPunk(vaultNFTs[0]);
    await punkVault.connect(carol).lock(1);
    await checkBalances();
    console.log();
    console.log("✓ Timelock.Medium");
    console.log();

    ///////////////////
    // Timelock.Long //
    ///////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    await expectRevert(punkVault.connect(carol).migrate(bob._address, 100));
    ////////////////////////////////////////////////////////////////////////
    await punkVault.connect(carol).initiateUnlock(2);
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////
    await punkVault.connect(carol).setBurnFees([2, 2, 2]);
    await punkToken.connect(alice).approve(punkVault.address, BASE);
    await expectRevert(punkVault.connect(alice).redeemPunk({ value: 1 }));
    await punkVault.connect(alice).redeemPunk({ value: 2 });
    await setApprovalForAll(alice, punkVault.address, aliceNFTs);
    await punkVault.connect(alice).mintPunkMultiple(aliceNFTs);
    const bobBal = parseInt((await cpm.balanceOf(bob._address)).toString());
    const vaultBal = parseInt(
      (await cpm.balanceOf(punkVault.address)).toString()
    );
    vaultNFTs = await getUserHoldings(punkVault.address, 20);
    await punkVault.connect(carol).migrate(bob._address, 7);
    expect(await punkToken.owner()).to.equal(punkVault.address);
    await punkVault.connect(carol).migrate(bob._address, 1);
    expect(await punkToken.owner()).to.equal(punkVault.address);
    await punkVault.connect(carol).migrate(bob._address, 1);
    expect(await punkToken.owner()).to.equal(bob._address);

    expect((await cpm.balanceOf(bob._address)).toString()).to.equal(
      (bobBal + vaultBal).toString()
    );

    for (let i = 0; i < vaultNFTs.length; i++) {
      await cpm.connect(bob).transferPunk(alice._address, vaultNFTs[i]);
    }
    await punkToken.connect(alice).burn(BASE.mul(9));
    await setApprovalForAll(alice, punkVault.address, vaultNFTs);
    await punkToken.connect(bob).transferOwnership(punkVault.address);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await punkVault.connect(alice).mintPunkMultiple(vaultNFTs);

    ////////////////////////////////////////////////////////////////////////

    bobNFTs = await getUserHoldings(bob._address, 20);
    const unit = BASE.div(100);
    await punkVault.connect(carol).setBurnFees([0, 0, 0]);
    await punkVault.connect(carol).setSupplierBounty([unit.toString(), 5]);

    await punkToken.connect(alice).approve(punkVault.address, BASE.mul(9));
    await punkVault.connect(alice).redeemPunkMultiple(4);
    for (let i = 0; i < 5; i++) {
      await expectRevert(
        punkVault.connect(alice).redeemPunk({
          value: unit
            .mul(i + 1)
            .sub(1)
            .toString(),
        })
      );
      await punkVault
        .connect(alice)
        .redeemPunk({ value: unit.mul(i + 1).toString() });
    }
    aliceNFTs = await getUserHoldings(alice._address, 20);
    let arr = aliceNFTs.splice(0, 2);

    await setApprovalForAll(alice, punkVault.address, arr);

    await punkVault.connect(alice).mintPunkMultiple(arr);

    await punkToken.connect(alice).approve(punkVault.address, BASE.mul(2));
    await expectRevert(
      punkVault.connect(alice).redeemPunkMultiple(2, {
        value: unit.mul(9).sub(1).toString(),
      })
    );
    await checkBalances();
    await punkVault.connect(alice).redeemPunkMultiple(2, {
      value: unit.mul(9).toString(),
    });
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, punkVault.address, aliceNFTs.slice(0, 2));
    let balance = await web3.eth.getBalance(punkVault.address);
    await punkVault.connect(alice).mintPunkMultiple(aliceNFTs.slice(0, 2));
    let newBalance = await web3.eth.getBalance(punkVault.address);
    expect(BigNumber.from(balance).sub(newBalance).toString()).to.equal(
      unit.mul(5 + 4).toString()
    );
    await setApprovalForAll(alice, punkVault.address, aliceNFTs.slice(2));
    balance = await web3.eth.getBalance(punkVault.address);
    await punkVault.connect(alice).mintPunkMultiple(aliceNFTs.slice(2));
    newBalance = await web3.eth.getBalance(punkVault.address);
    expect(BigNumber.from(balance).sub(newBalance).toString()).to.equal(
      unit.mul(3 + 2 + 1).toString()
    );
    let tBal = await punkToken.balanceOf(alice._address);
    await punkToken.connect(alice).approve(punkVault.address, tBal);
    let num = 5 + 4 + 3 + 2 + 1;

    await expectRevert(
      punkVault
        .connect(alice)
        .redeemPunkMultiple(BigNumber.from(tBal).div(BASE), {
          value: unit.mul(num).sub(1).toString(),
        })
    );
    await punkVault
      .connect(alice)
      .redeemPunkMultiple(BigNumber.from(tBal).div(BASE), {
        value: unit.mul(num).toString(),
      });

    ////////////////////////////////////////////////////////////////////////
    await punkVault.connect(carol).setSupplierBounty([0, 0]);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, punkVault.address, aliceNFTs);
    await punkVault
      .connect(alice)
      .mintPunkMultiple(aliceNFTs.slice(0, aliceNFTs.length - 1));
    await punkVault.connect(carol).lock(2);

    console.log("✓ Profitable: setBurnFees");
    console.log();

    console.log("✓ Timelock.Long");

    ///////////////////////////////////////////////////////////////
    // Pausable: *.pause, *.unpause & PunkVaultSafe: *.simpleRedeem //
    ///////////////////////////////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await expectRevert(punkVault.connect(alice).pause());
    await expectRevert(punkVault.connect(alice).unpause());
    await punkToken.connect(alice).approve(punkVault.address, BASE);
    await expectRevert(punkVault.connect(alice).simpleRedeem());
    await punkVault.connect(carol).pause();
    let aliceBal = await punkToken.balanceOf(alice._address);
    balance = await punkToken.balanceOf(alice._address);
    await punkVault.connect(alice).simpleRedeem();
    expect((await punkToken.balanceOf(alice._address)).toString()).to.equal(
      balance.sub(BASE).toString()
    );
    await checkBalances();
    console.log();
    console.log("✓ Pausable");
    console.log();

    console.log("-- DONE --\n");
  });
});

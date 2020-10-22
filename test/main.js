const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { check } = require("yargs");
const { expectRevert } = require("../utils/expectRevert");

const eligibleIds = require("../data/punk/punkAttr5");

const BASE = BigNumber.from(10).pow(18);
const zeroAddress = "0x0000000000000000000000000000000000000000";
describe("NFTX", function () {
  this.timeout(0);
  it("Should run as expected", async function () {
    const checkBalances = async (alwaysPrint = false) => {
      let ownerBal = await zToken.balanceOf(initialOwner._address);
      let aliceBal = await zToken.balanceOf(alice._address);
      let bobBal = await zToken.balanceOf(bob._address);
      let carolBal = await zToken.balanceOf(carol._address);
      let vaultBal = await zToken.balanceOf(nftx.address);
      let supply = await zToken.totalSupply();
      let vaultNFTBal = await cpm.balanceOf(nftx.address);

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
        console.log("  ", vaultBal.toString(), ": nftx \n");
        console.log("  ", supply.toString(), ": totalSupply\n");
        console.log("ERC721 \n");
        console.log("  ", vaultNFTBal.toString(), ": nftx \n");
        return false;
      }
      return true;
    };

    ///////////////////
    // Initialize... //
    ///////////////////

    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const cpm = await Cpm.deploy();
    await cpm.deployed();

    const Nftx = await ethers.getContractFactory("NFTX");
    const nftx = await Nftx.deploy(cpm.address);
    await nftx.deployed();

    const XController = await ethers.getContractFactory("XController");
    const xController = await XController.deploy(nftx.address);
    await xController.deployed();

    const [initialOwner, alice, bob, carol] = await ethers.getSigners();

    await nftx.connect(initialOwner).transferOwnership(xController.address);

    // Initialize PUNK-ZOMBIE

    const XToken = await ethers.getContractFactory("XToken");
    const zToken = await XToken.deploy("Punk-Zombie", "PUNK-ZOMBIE");
    await zToken.deployed();
    await zToken.transferOwnership(nftx.address);
    const zVaultId = (
      await nftx.connect(alice).createVault(zToken.address, cpm.address)
    ).value.toNumber();
    await nftx.connect(alice).setSupplierBounty(zVaultId, 0, 0, 0);
    for (let i = 0; i < eligibleIds().length; i += 150) {
      let j = eligibleIds().length <= i + 150 ? eligibleIds().length : i + 150;
      await nftx
        .connect(alice)
        .setIsEligible(zVaultId, eligibleIds().splice(i, j), true);
    }
    await nftx.connect(alice).finalizeVault(zVaultId);

    /////////////////////////////////////
    // NFTX: *.mint *.redeem //
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
        .offerPunkForSaleToAddress(tokenId, 0, nftx.address);
      await nftx.connect(signer).mint(zVaultId, [tokenId], { value: value });
    };

    const approveAndRedeem = async (signer, value = 0) => {
      await zToken.connect(signer).approve(nftx.address, BASE);
      await nftx.connect(signer).redeem(zVaultId, 1, { value: value });
    };
    for (let _i = 0; _i < 10; _i++) {
      const i = eligibleIds()[_i];
      await approveAndMint(alice, i);
      const i2 = eligibleIds()[_i + 10];
      await approveAndMint(bob, i2);
    }
    for (let _i = 0; _i < 10; _i++) {
      await approveAndRedeem(alice);
      await approveAndRedeem(bob);
    }
    const getUserHoldings = async (address, tokenSupply) => {
      let list = [];
      for (let _i = 0; _i < tokenSupply; _i++) {
        const i = eligibleIds()[_i];
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
    console.log("✓ NFTX: mint, redeem");
    console.log();

    await checkBalances();

    /////////////////////////////
    // NFTX: *.mintAndRedeem //
    /////////////////////////////

    await expectRevert(
      nftx.connect(alice).mintAndRedeem(zVaultId, [bobNFTs[0]])
    );
    await expectRevert(
      nftx.connect(alice).mintAndRedeem(zVaultId, [aliceNFTs[0]])
    );
    await cpm
      .connect(alice)
      .offerPunkForSaleToAddress(aliceNFTs[0], 0, nftx.address);
    await nftx.connect(alice).mintAndRedeem(zVaultId, [aliceNFTs[0]]);
    expect(await cpm.punkIndexToAddress(aliceNFTs[0])).to.equal(alice._address);
    await cpm
      .connect(bob)
      .offerPunkForSaleToAddress(bobNFTs[0], 0, nftx.address);
    await cpm
      .connect(bob)
      .offerPunkForSaleToAddress(bobNFTs[1], 0, nftx.address);

    await nftx.connect(bob).mint(zVaultId, [bobNFTs[0]]);
    await nftx.connect(bob).mint(zVaultId, [bobNFTs[1]]);
    await cpm
      .connect(alice)
      .offerPunkForSaleToAddress(aliceNFTs[0], 0, nftx.address);
    await nftx.connect(alice).mintAndRedeem(zVaultId, [aliceNFTs[0]]);
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
        .offerPunkForSaleToAddress(newSelection, 0, nftx.address);
      await nftx.connect(alice).mintAndRedeem(zVaultId, [newSelection]);
    }
    await zToken.connect(bob).approve(nftx.address, BASE.mul(2).toString());
    await nftx.connect(bob).redeem(zVaultId, 1);
    await nftx.connect(bob).redeem(zVaultId, 1);
    console.log(selections);
    console.log();
    console.log("✓ NFTX: mintAndRedeem");

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
    // NFTX: *.mintXMultiple, *.redeemXMultiple //
    //////////////////////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await setApprovalForAll(alice, nftx.address, aliceNFTs);
    await setApprovalForAll(bob, nftx.address, bobNFTs);
    await nftx.connect(alice).mint(zVaultId, aliceNFTs.slice(0, 5));
    for (let i = 0; i < 5; i++) {
      expect(await cpm.punkIndexToAddress(aliceNFTs[i])).to.equal(nftx.address);
    }
    for (let i = 5; i < 10; i++) {
      expect(await cpm.punkIndexToAddress(aliceNFTs[i])).to.equal(
        alice._address
      );
    }
    const FIVE = BASE.mul(5).toString();
    expect((await zToken.balanceOf(alice._address)).toString()).to.equal(FIVE);
    await zToken.connect(alice).approve(nftx.address, FIVE);
    await nftx.connect(alice).redeem(zVaultId, 5);

    for (let i = 0; i < 10; i++) {
      expect(await cpm.punkIndexToAddress(aliceNFTs[i])).to.equal(
        alice._address
      );
    }
    expect((await zToken.balanceOf(alice._address)).toString()).to.equal("0");

    console.log();
    console.log("✓ NFTX: mintXMultiple, redeemXMultiple");
    console.log();

    await checkBalances();

    /////////////////////////////////////
    // NFTX: *.mintAndRedeemMultiple //
    /////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await nftx.connect(bob).mint(zVaultId, bobNFTs);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await setApprovalForAll(alice, nftx.address, aliceNFTs);
    await nftx.connect(alice).mintAndRedeem(zVaultId, aliceNFTs);
    let _aliceNFTs = await getUserHoldings(alice._address, 20);
    let list = [];
    for (let i = 0; i < 10; i++) {
      const item = _aliceNFTs[i];
      list.push(aliceNFTs.includes(item) ? 0 : 1);
    }
    console.log(list);
    await zToken.connect(bob).approve(nftx.address, BASE.mul(10).toString());
    await nftx.connect(bob).redeem(zVaultId, 10);

    console.log();
    console.log("✓ NFTX: mintAndRedeemMultiple");

    await checkBalances();

    ////////////////
    // Manageable //
    ////////////////

    await xController.connect(initialOwner).transferOwnership(carol._address);
    await expectRevert(
      xController.connect(carol).migrate(zVaultId, 100, carol._address)
    );
    await xController.connect(carol).initiateUnlock(0);
    await xController.connect(carol).initiateUnlock(1);
    await expectRevert(
      xController.connect(carol).changeTokenName(zVaultId, "Name")
    );
    await expectRevert(
      xController.connect(carol).changeTokenSymbol(zVaultId, "NAME")
    );
    await xController.connect(carol).initiateUnlock(2);
    await expectRevert(
      xController.connect(carol).migrate(zVaultId, 100, carol._address)
    );
    await checkBalances();
    await xController.connect(carol).lock(0);
    await xController.connect(carol).lock(1);
    await xController.connect(carol).lock(2);

    await checkBalances();
    console.log();
    console.log("✓ Manageable");
    console.log();

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    ////////////////////
    // Timelock.Short //
    ////////////////////
    // TODO:
    ////////////////////////////////////////////////////////////////////////

    console.log("✓ Timelock.Short");
    console.log();

    /////////////////////
    // Timelock.Medium //
    /////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);

    await checkBalances();
    await expectRevert(
      xController.connect(carol).changeTokenName(zVaultId, "Name")
    );
    await expectRevert(
      xController.connect(carol).changeTokenSymbol(zVaultId, "NAME")
    );
    await expectRevert(
      xController.connect(carol).setMintFees(zVaultId, 1, 1, 0)
    );
    await expectRevert(
      xController.connect(carol).setBurnFees(zVaultId, 1, 1, 0)
    );
    await expectRevert(
      xController.connect(carol).setDualFees(zVaultId, 1, 1, 0)
    );
    ////////////////////////////////////////////////////////////////////////
    await xController.connect(carol).initiateUnlock(1);
    await xController.connect(carol).initiateUnlock(2); // because setFeesArray
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////

    // Manageable: *.changeTokenName, *.changeTokenSymbol

    await expectRevert(
      xController.connect(alice).changeTokenName(zVaultId, "Name")
    );
    await expectRevert(
      xController.connect(alice).changeTokenSymbol(zVaultId, "NAME")
    );
    await xController.connect(carol).changeTokenName(zVaultId, "Name");
    await xController.connect(carol).changeTokenSymbol(zVaultId, "NAME");
    expect(await zToken.name()).to.equal("Name");
    expect(await zToken.symbol()).to.equal("NAME");
    await checkBalances();

    console.log("✓ Manageable: changeTokenName, changeTokenSymbol");
    console.log();
    //
    // Profitable: *.setMintFees
    await setApprovalForAll(alice, nftx.address, aliceNFTs.slice(0, 5));

    await xController.connect(carol).setMintFees(zVaultId, 2, 2, 0);
    await expectRevert(
      nftx.connect(alice).mint(zVaultId, [aliceNFTs[0]], { value: 1 })
    );
    await nftx.connect(alice).mint(zVaultId, [aliceNFTs[0]], { value: 2 });
    await expectRevert(
      nftx.connect(alice).mint(zVaultId, aliceNFTs.slice(1, 5), { value: 7 })
    );
    await nftx
      .connect(alice)
      .mint(zVaultId, aliceNFTs.slice(1, 5), { value: 8 });
    await checkBalances();

    console.log("✓ Profitable: setMintFees");
    console.log();

    // Profitable: *.setDualFees
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, nftx.address, aliceNFTs.slice(0, 5));
    await xController.connect(carol).setDualFees(zVaultId, 2, 2, 0);
    await expectRevert(
      nftx.connect(alice).mintAndRedeem(zVaultId, [aliceNFTs[0]], { value: 1 })
    );
    await nftx
      .connect(alice)
      .mintAndRedeem(zVaultId, [aliceNFTs[0]], { value: 2 });
    await expectRevert(
      nftx
        .connect(alice)
        .mintAndRedeem(zVaultId, aliceNFTs.slice(1, 5), { value: 7 })
    );
    await nftx
      .connect(alice)
      .mintAndRedeem(zVaultId, aliceNFTs.slice(1, 5), { value: 8 });
    ////////////////////////////////////////////////////////////////////////
    await checkBalances();
    console.log("✓ Profitable: setDualFees");
    console.log();

    // Profitable: *.setIsIntegrator, *.isIntegrator, *getNumIntegrators
    await xController.connect(carol).setMintFees(zVaultId, 0, 0, 0);
    await xController.connect(carol).setDualFees(zVaultId, 0, 0, 0);
    aliceNFTs = await getUserHoldings(alice._address, 20);

    await expectRevert(
      xController.connect(alice).setIsIntegrator(alice._address, true)
    );
    await cpm
      .connect(alice)
      .offerPunkForSaleToAddress(aliceNFTs[0], 0, nftx.address);
    expect((await nftx.numIntegrators()).toString()).to.equal("0");
    expect(await nftx.isIntegrator(alice._address)).to.equal(false);
    await xController.connect(carol).setIsIntegrator(alice._address, true);
    expect((await nftx.numIntegrators()).toString()).to.equal("1");
    expect(await nftx.isIntegrator(alice._address)).to.equal(true);
    await nftx.connect(alice).mint(zVaultId, [aliceNFTs[0]]);

    await zToken.connect(alice).approve(nftx.address, BASE.mul(4).toString());
    await nftx.connect(alice).redeem(zVaultId, 4);
    await xController.connect(carol).setIsIntegrator(alice._address, false);
    expect((await nftx.numIntegrators()).toString()).to.equal("0");
    expect(await nftx.isIntegrator(alice._address)).to.equal(false);

    ///////////////////////////////////////////////////
    // Controllable: *.setController, *.directRedeem //
    ///////////////////////////////////////////////////

    await checkBalances();
    let vaultNFTs = await getUserHoldings(nftx.address, 20);

    await expectRevert(
      xController.connect(alice).setIsIntegrator(alice._address, true)
    );
    await expectRevert(
      xController.connect(bob).setIsIntegrator(alice._address, true)
    );
    await zToken.connect(alice).approve(nftx.address, BASE);
    await expectRevert(
      nftx.connect(alice).directRedeem(zVaultId, [vaultNFTs[0]])
    );
    await expectRevert(
      nftx.connect(alice).directRedeem(zVaultId, [vaultNFTs[0]])
    );
    await xController.connect(carol).setIsIntegrator(alice._address, true);
    await nftx.connect(alice).directRedeem(zVaultId, [vaultNFTs[0]]);
    expect(await cpm.punkIndexToAddress(vaultNFTs[0])).to.equal(alice._address);

    console.log("✓ Controllable");

    await xController.connect(carol).setIsIntegrator(alice._address, false);
    await setApprovalForAll(alice, nftx.address, vaultNFTs.slice(0, 1));
    await nftx.connect(alice).mint(zVaultId, [vaultNFTs[0]]);
    await xController.connect(carol).lock(1);
    await xController.connect(carol).lock(2); // because setFeesArray
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
      xController.connect(carol).migrate(zVaultId, 100, bob._address)
    );
    ////////////////////////////////////////////////////////////////////////
    await xController.connect(carol).initiateUnlock(2);
    console.log("waiting...");
    console.log();
    await new Promise((resolve) => setTimeout(() => resolve(), 3000));
    ////////////////////////////////////////////////////////////////////////
    await xController.connect(carol).setBurnFees(zVaultId, 2, 2, 0);
    await zToken.connect(alice).approve(nftx.address, BASE);
    await expectRevert(nftx.connect(alice).redeem(zVaultId, 1, { value: 1 }));
    await nftx.connect(alice).redeem(zVaultId, 1, { value: 2 });
    await setApprovalForAll(alice, nftx.address, aliceNFTs);
    await nftx.connect(alice).mint(zVaultId, aliceNFTs);
    const bobBal = parseInt((await cpm.balanceOf(bob._address)).toString());
    const vaultBal = parseInt((await cpm.balanceOf(nftx.address)).toString());
    vaultNFTs = await getUserHoldings(nftx.address, 20);
    await xController.connect(carol).migrate(zVaultId, 7, bob._address);
    await xController.connect(carol).migrate(zVaultId, 1, bob._address);
    await xController.connect(carol).migrate(zVaultId, 1, bob._address);
    await xController
      .connect(carol)
      .transferTokenOwnership(zVaultId, bob._address);
    expect(await zToken.owner()).to.equal(bob._address);
    expect((await cpm.balanceOf(bob._address)).toString()).to.equal(
      (bobBal + vaultBal).toString()
    );
    for (let i = 0; i < vaultNFTs.length; i++) {
      await cpm.connect(bob).transferPunk(alice._address, vaultNFTs[i]);
    }
    await zToken.connect(alice).burn(BASE.mul(9));
    await setApprovalForAll(alice, nftx.address, vaultNFTs);
    await zToken.connect(bob).transferOwnership(nftx.address);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await nftx.connect(alice).mint(zVaultId, vaultNFTs);

    ////////////////////////////////////////////////////////////////////////

    bobNFTs = await getUserHoldings(bob._address, 20);
    const unit = BASE.div(100);
    await xController.connect(carol).setBurnFees(zVaultId, 0, 0, 0);
    await xController
      .connect(carol)
      .setSupplierBounty(zVaultId, unit.mul(5).toString(), 0, 5);
    await zToken.connect(alice).approve(nftx.address, BASE.mul(9));
    await nftx.connect(alice).redeem(zVaultId, 4);
    for (let i = 0; i < 5; i++) {
      await expectRevert(
        nftx.connect(alice).redeem(zVaultId, 1, {
          value: unit
            .mul(i + 1)
            .sub(1)
            .toString(),
        })
      );
      await nftx
        .connect(alice)
        .redeem(zVaultId, 1, { value: unit.mul(i + 1).toString() });
    }
    aliceNFTs = await getUserHoldings(alice._address, 20);
    let arr = aliceNFTs.splice(0, 2);
    await setApprovalForAll(alice, nftx.address, arr);
    await nftx.connect(alice).mint(zVaultId, arr);
    await zToken.connect(alice).approve(nftx.address, BASE.mul(2));
    await expectRevert(
      nftx.connect(alice).redeem(zVaultId, 2, {
        value: unit.mul(9).sub(1).toString(),
      })
    );
    await checkBalances();
    await nftx.connect(alice).redeem(zVaultId, 2, {
      value: unit.mul(9).toString(),
    });
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, nftx.address, aliceNFTs.slice(0, 2));
    let balance = await web3.eth.getBalance(nftx.address);
    await nftx.connect(alice).mint(zVaultId, aliceNFTs.slice(0, 2));
    let newBalance = await web3.eth.getBalance(nftx.address);
    expect(BigNumber.from(balance).sub(newBalance).toString()).to.equal(
      unit.mul(5 + 4).toString()
    );
    await setApprovalForAll(alice, nftx.address, aliceNFTs.slice(2));
    balance = await web3.eth.getBalance(nftx.address);
    await nftx.connect(alice).mint(zVaultId, aliceNFTs.slice(2));

    newBalance = await web3.eth.getBalance(nftx.address);
    expect(BigNumber.from(balance).sub(newBalance).toString()).to.equal(
      unit.mul(3 + 2 + 1).toString()
    );
    let tBal = await zToken.balanceOf(alice._address);
    await zToken.connect(alice).approve(nftx.address, tBal);
    let num = 5 + 4 + 3 + 2 + 1;

    await expectRevert(
      nftx.connect(alice).redeem(zVaultId, BigNumber.from(tBal).div(BASE), {
        value: unit.mul(num).sub(1).toString(),
      })
    );
    await nftx.connect(alice).redeem(zVaultId, BigNumber.from(tBal).div(BASE), {
      value: unit.mul(num).toString(),
    });
    ////////////////////////////////////////////////////////////////////////
    await xController.connect(carol).setSupplierBounty(zVaultId, 0, 0, 0);
    aliceNFTs = await getUserHoldings(alice._address, 20);
    await setApprovalForAll(alice, nftx.address, aliceNFTs);
    await nftx
      .connect(alice)
      .mint(zVaultId, aliceNFTs.slice(0, aliceNFTs.length - 1));
    await xController.connect(carol).lock(2);

    console.log("✓ Profitable: setBurnFees");
    console.log();

    console.log("✓ Timelock.Long");

    ///////////////////////////////////////////////////////////////
    // Pausable: *.pause, *.unpause & XVaultSafe: *.simpleRedeem //
    ///////////////////////////////////////////////////////////////

    aliceNFTs = await getUserHoldings(alice._address, 20);
    bobNFTs = await getUserHoldings(bob._address, 20);
    await expectRevert(xController.connect(alice).pause());
    await expectRevert(xController.connect(alice).unpause());
    await zToken.connect(alice).approve(nftx.address, BASE);
    await xController.connect(carol).pause();
    let aliceBal = await zToken.balanceOf(alice._address);
    balance = await zToken.balanceOf(alice._address);
    await nftx.connect(alice).redeem(zVaultId, 1);
    expect((await zToken.balanceOf(alice._address)).toString()).to.equal(
      balance.sub(BASE).toString()
    );
    await checkBalances();
    console.log();
    console.log("✓ Pausable");
    console.log();

    console.log("-- DONE --\n");
  });
});

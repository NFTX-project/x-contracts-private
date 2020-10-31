const { BigNumber } = require("ethers");
const { expect } = require("chai");
const { expectRevert } = require("../utils/expectRevert");
const {
  setupD2,
  balancesOf,
  approveAndMintD2,
  checkBalancesD2,
  approveAndRedeemD2,
  approveAndRedeem,
  cleanupD2,
} = require("./_helpers");

const BASE = BigNumber.from(10).pow(18);
const UNIT = BASE.div(100);

const runVaultTestsD2 = async (nftx, asset, xToken, signers, vaultId) => {
  const [owner, misc, alice, bob, carol, dave, eve] = signers;

  //////////////////
  // mint, redeem //
  //////////////////

  const runMintRedeem = async () => {
    console.log("Testing (D2): mint, redeem...\n");
    await setupD2(nftx, asset, signers);
    const [aliceBal, bobBal] = await balancesOf(asset, [alice, bob]);

    await approveAndMintD2(nftx, asset, aliceBal, alice, vaultId, 0);
    await approveAndMintD2(nftx, asset, bobBal, bob, vaultId, 0);
    await checkBalancesD2(nftx, asset, xToken, [alice, bob]);
    await approveAndRedeemD2(nftx, xToken, aliceBal, alice, vaultId, 0);
    await approveAndRedeemD2(nftx, xToken, bobBal, bob, vaultId, 0);

    await checkBalancesD2(nftx, asset, xToken, [alice, bob]);
    await cleanupD2(nftx, asset, xToken, signers, vaultId);
  };

  ////////////////////////
  // mintFees, burnFees //
  ////////////////////////

  const runMintFeesBurnFees = async () => {
    console.log("Testing (D2): mintFees, burnFees...\n");
    await setupD2(nftx, asset, signers);
    const [aliceBal] = await balancesOf(asset, [alice]);
    await nftx.connect(owner).setMintFees(vaultId, UNIT.mul(5), UNIT);
    await nftx.connect(owner).setBurnFees(vaultId, UNIT.mul(5), UNIT);

    const n = aliceBal.div(BASE);
    const amount = UNIT.mul(5).add(UNIT.mul(n - 1));
    await expectRevert(
      approveAndMintD2(nftx, asset, aliceBal, alice, vaultId, amount.sub(1))
    );
    await checkBalancesD2(nftx, asset, xToken, [alice]);
    await approveAndMintD2(nftx, asset, aliceBal, alice, vaultId, amount);
    await expectRevert(
      approveAndRedeemD2(nftx, xToken, aliceBal, alice, vaultId, amount.sub(1))
    );
    await approveAndRedeemD2(nftx, xToken, aliceBal, alice, vaultId, amount);

    await nftx.connect(owner).setMintFees(vaultId, 0, 0);
    await nftx.connect(owner).setBurnFees(vaultId, 0, 0);
    await checkBalancesD2(nftx, asset, xToken, [alice]);
    await cleanupD2(nftx, asset, xToken, signers, vaultId);
  };

  ////////////////////
  // supplierBounty //
  ////////////////////

  const runSupplierBounty = async () => {
    console.log("Testing (D2): supplierBounty...\n");
    await setupD2(nftx, asset, signers);
    const [aliceBal] = await balancesOf(asset, [alice]);
    await nftx.connect(owner).depositETH(vaultId, { value: UNIT.mul(100) });
    await nftx
      .connect(owner)
      .setSupplierBounty(vaultId, UNIT.mul(10), BASE.mul(5));

    let nftxBal1 = BigNumber.from(await web3.eth.getBalance(nftx.address));
    let aliceBal1 = BigNumber.from(await web3.eth.getBalance(alice._address));
    console.log("here-a");
    await approveAndMintD2(nftx, asset, aliceBal, alice, vaultId, 0);
    console.log("here-b");
    let nftxBal2 = BigNumber.from(await web3.eth.getBalance(nftx.address));
    let aliceBal2 = BigNumber.from(await web3.eth.getBalance(alice._address));
    expect(nftxBal2.toString()).to.equal(
      nftxBal1.sub(UNIT.mul(10 + 8 + 6 + 4 + 2)).toString()
    );
  };

  //////////////////////////
  // Run Feature Tests... //
  //////////////////////////

  await runMintRedeem();
  await runMintFeesBurnFees();
  await runSupplierBounty();
  console.log("-- DONE D2 --");
};

exports.runVaultTestsD2 = runVaultTestsD2;

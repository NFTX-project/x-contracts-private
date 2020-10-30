const { BigNumber } = require("ethers");
const { expect } = require("chai");
const { expectRevert } = require("../utils/expectRevert");

const BASE = BigNumber.from(10).pow(18);
const UNIT = BASE.div(100);

const {
  transferNFTs,
  setup,
  cleanup,
  holdingsOf,
  checkBalances,
  approveEach,
  approveAndMint,
  approveAndRedeem,
} = require("./_helpers");

const runVaultTests = async (
  nftx,
  nft,
  token,
  signers,
  vaultId,
  allNftIds,
  eligIds,
  isPV,
  isD2
) => {
  const [owner, misc, alice, bob, carol, dave, eve] = signers;

  //////////////////
  // mint, redeem //
  //////////////////

  const runMintRedeem = async () => {
    console.log("Testing: mint, redeem...\n");
    await setup(nftx, nft, signers, vaultId, isPV, eligIds);
    let [aliceNFTs, bobNFTs] = await holdingsOf(
      nft,
      eligIds,
      [alice, bob],
      isPV
    );
    await approveAndMint(nftx, nft, aliceNFTs, alice, vaultId, 0, isPV);
    await approveAndMint(nftx, nft, bobNFTs, bob, vaultId, 0, isPV);
    await checkBalances(nftx, nft, token, signers.slice(2), isPV);
    await approveAndRedeem(nftx, token, aliceNFTs.length, alice, vaultId);
    await approveAndRedeem(nftx, token, bobNFTs.length, bob, vaultId);

    [aliceNFTs, bobNFTs] = await holdingsOf(nft, eligIds, [alice, bob], isPV);
    console.log(aliceNFTs);
    console.log(bobNFTs, "\n");
    await checkBalances(nftx, nft, token, signers.slice(2), isPV);
    await cleanup(nftx, nft, token, signers, vaultId, isPV, eligIds);
  };

  ///////////////////
  // mintAndRedeem //
  ///////////////////

  const runMintAndRedeem = async () => {
    console.log("Testing: mintAndRedeem...\n");
    await setup(nftx, nft, signers, vaultId, isPV, eligIds);
    let [aliceNFTs, bobNFTs] = await holdingsOf(
      nft,
      eligIds,
      [alice, bob],
      isPV
    );
    await approveAndMint(nftx, nft, aliceNFTs, alice, vaultId, 0, isPV);

    await approveEach(nft, bobNFTs, bob, nftx.address, isPV);
    await nftx.connect(bob).mintAndRedeem(vaultId, bobNFTs);
    await checkBalances(nftx, nft, token, signers.slice(2), isPV);

    [bobNFTs] = await holdingsOf(nft, eligIds, [bob], isPV);
    console.log(bobNFTs, "\n");
    await cleanup(nftx, nft, token, signers, vaultId, isPV, eligIds);
  };

  ////////////////////////
  // mintFees, burnFees //
  ////////////////////////

  const runMintFeesBurnFees = async () => {
    console.log("Testing: mintFees, burnFees...\n");
    await setup(nftx, nft, signers, vaultId, isPV, eligIds);
    let [aliceNFTs, bobNFTs] = await holdingsOf(
      nft,
      eligIds,
      [alice, bob],
      isPV
    );
    await nftx.connect(owner).setMintFees(vaultId, UNIT.mul(5), UNIT);
    await nftx.connect(owner).setBurnFees(vaultId, UNIT.mul(5), UNIT);

    const n = aliceNFTs.length;
    let amount = UNIT.mul(5).add(UNIT.mul(n - 1));
    await expectRevert(
      approveAndMint(nftx, nft, aliceNFTs, alice, vaultId, amount.sub(1), isPV)
    );
    await approveAndMint(nftx, nft, aliceNFTs, alice, vaultId, amount, isPV);
    await expectRevert(
      approveAndRedeem(nftx, token, n, alice, vaultId, amount.sub(1))
    );
    await approveAndRedeem(nftx, token, n, alice, vaultId, amount);
    await checkBalances(nftx, nft, token, signers.slice(2), isPV);

    await nftx.connect(owner).setMintFees(vaultId, 0, 0);
    await nftx.connect(owner).setBurnFees(vaultId, 0, 0);
    await cleanup(nftx, nft, token, signers, vaultId, isPV, eligIds);
  };

  //////////////
  // dualFees //
  //////////////

  const runDualFees = async () => {
    console.log("Testing: dualFees...\n");
    await setup(nftx, nft, signers, vaultId, isPV, eligIds);
    let [aliceNFTs, bobNFTs] = await holdingsOf(
      nft,
      eligIds,
      [alice, bob],
      isPV
    );
    await nftx.connect(owner).setDualFees(vaultId, UNIT.mul(5), UNIT);
    await approveAndMint(nftx, nft, aliceNFTs, alice, vaultId, 0, isPV);

    await approveEach(nft, bobNFTs, bob, nftx.address, isPV);
    let amount = UNIT.mul(5).add(UNIT.mul(bobNFTs.length - 1));
    await expectRevert(
      nftx
        .connect(bob)
        .mintAndRedeem(vaultId, bobNFTs, { value: amount.sub(1) })
    );
    await nftx.connect(bob).mintAndRedeem(vaultId, bobNFTs, { value: amount });

    await nftx.connect(owner).setDualFees(vaultId, 0, 0);
    await cleanup(nftx, nft, token, signers, vaultId, isPV, eligIds);
  };

  ////////////////////
  // supplierBounty //
  ////////////////////

  const runSupplierBounty = async () => {
    console.log("Testing: supplierBounty...\n");
    await setup(nftx, nft, signers, vaultId, isPV, eligIds);
    let [aliceNFTs, bobNFTs] = await holdingsOf(
      nft,
      eligIds,
      [alice, bob],
      isPV
    );
    await nftx.connect(owner).depositETH(vaultId, { value: UNIT.mul(100) });
    await nftx.connect(owner).setSupplierBounty(vaultId, UNIT.mul(10), 5);

    let nftxBal1 = BigNumber.from(await web3.eth.getBalance(nftx.address));
    let aliceBal1 = BigNumber.from(await web3.eth.getBalance(alice._address));
    await approveAndMint(nftx, nft, aliceNFTs, alice, vaultId, 0, isPV);
    let nftxBal2 = BigNumber.from(await web3.eth.getBalance(nftx.address));
    let aliceBal2 = BigNumber.from(await web3.eth.getBalance(alice._address));
    expect(nftxBal2.toString()).to.equal(
      nftxBal1.sub(UNIT.mul(10 + 8 + 6 + 4 + 2)).toString()
    );
    expect(aliceBal2.gt(aliceBal1)).to.equal(true);
    await approveAndRedeem(
      nftx,
      token,
      aliceNFTs.length,
      alice,
      vaultId,
      UNIT.mul(10 + 8 + 6 + 4 + 2).toString()
    );
    let nftxBal3 = BigNumber.from(await web3.eth.getBalance(nftx.address));
    let aliceBal3 = BigNumber.from(await web3.eth.getBalance(alice._address));
    expect(nftxBal3.toString()).to.equal(nftxBal1.toString());
    expect(aliceBal3.lt(aliceBal2)).to.equal(true);

    await nftx.connect(owner).setSupplierBounty(vaultId, 0, 0);
    await cleanup(nftx, nft, token, signers, vaultId, isPV, eligIds);
  };

  ////////////////
  // isEligible //
  ////////////////

  const runIsEligible = async () => {
    console.log("Testing: isEligible...\n");
    await setup(nftx, nft, signers, vaultId, isPV, eligIds);
    let [aliceNFTs] = await holdingsOf(nft, eligIds, [alice], isPV);
    let nftIds = eligIds.slice(0, 2).map((n) => n + 1);
    await transferNFTs(nftx, nft, nftIds, misc, alice, isPV);

    await expectRevert(
      approveAndMint(nftx, nft, nftIds, alice, vaultId, 0, isPV)
    );

    await approveAndMint(
      nftx,
      nft,
      eligIds.slice(0, 2),
      alice,
      vaultId,
      0,
      isPV
    );

    await cleanup(nftx, nft, token, signers, vaultId, isPV, allNftIds);
  };

  //////////////////////////
  // Run Feature Tests... //
  //////////////////////////

  await runMintRedeem();
  await runMintAndRedeem();
  await runMintFeesBurnFees();
  await runDualFees();
  await runSupplierBounty();
  eligIds[1] - eligIds[0] > 1 && (await runIsEligible());

  console.log("\n-- Vault tests complete --\n\n");
};

exports.runVaultTests = runVaultTests;

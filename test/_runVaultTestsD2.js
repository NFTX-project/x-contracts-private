const {
  setupD2,
  balancesOf,
  approveAndMintD2,
  checkBalancesD2,
  approveAndRedeemD2,
  approveAndRedeem,
  cleanupD2,
} = require("./_helpers");

const runVaultTestsD2 = async (nftx, asset, xToken, signers, vaultId) => {
  const [owner, misc, alice, bob, carol, dave, eve] = signers;

  //////////////////
  // mint, redeem //
  //////////////////

  const runMintRedeemD2 = async () => {
    console.log("Testing (D2): mint, redeem...\n");
    await setupD2(nftx, asset, signers);
    let [aliceBal, bobBal] = await balancesOf(asset, signers.slice(2));

    await approveAndMintD2(nftx, asset, aliceBal, alice, vaultId, 0);
    await approveAndMintD2(nftx, asset, bobBal, bob, vaultId, 0);
    await checkBalancesD2(nftx, asset, xToken, [alice, bob]);
    await approveAndRedeemD2(nftx, xToken, aliceBal, alice, vaultId, 0);
    await approveAndRedeemD2(nftx, xToken, bobBal, bob, vaultId, 0);

    await checkBalancesD2(nftx, asset, xToken, [alice, bob]);
    await cleanupD2(nftx, asset, xToken, signers, vaultId);
  };

  //////////////////////////
  // Run Feature Tests... //
  //////////////////////////

  await runMintRedeemD2();
  console.log("-- DONE D2 --");
};

exports.runVaultTestsD2 = runVaultTestsD2;

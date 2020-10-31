const { runVaultTests } = require("./_runVaultTests");
const { runVaultTestsD2 } = require("./_runVaultTestsD2");
const { getIntArray, initializeAssetTokenVault } = require("./_helpers");

describe("NFTX", function () {
  this.timeout(0);
  it("Should run as expected", async function () {
    console.log('');
    ///////////////////////////////////////////////////////////////
    // Initialize NFTX ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////
    
    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const cpm = await Cpm.deploy();
    await cpm.deployed();

    const Nftx = await ethers.getContractFactory("NFTX");
    const nftx = await Nftx.deploy(cpm.address);
    await nftx.deployed();

    const signers = await ethers.getSigners();
    const [owner, misc, alice, bob, carol, dave, eve] = signers;

    const allNftIds = getIntArray(0, 40);

    ///////////////
    // NFT-basic //
    ///////////////

    const runNftBasic = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        "NFT-A",
        "XToken-A",
        allNftIds,
        false,
        false
      );
      const eligIds = getIntArray(0, 20);
      await runVaultTests(
        nftx,
        asset,
        xToken,
        signers,
        vaultId,
        allNftIds,
        eligIds,
        false,
        false
      );
    };

    ////////////////
    // Punk-basic //
    ////////////////

    const runPunkBasic = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        cpm,
        "Punk-Basic",
        allNftIds,
        true,
        false
      );
      const eligIds = getIntArray(0, 20);
      await runVaultTests(
        nftx,
        asset,
        xToken,
        signers,
        vaultId,
        allNftIds,
        eligIds,
        true,
        false
      );
    };

    /////////////////
    // NFT-special //
    /////////////////

    let _asset;
    const runNftSpecial = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        "NFT-B",
        "XToken-B1",
        allNftIds,
        false,
        false
      );
      const eligIds = getIntArray(0, 20).map((n) => n * 2);
      nftx.connect(owner).setNegateEligibility(vaultId, false);
      nftx.connect(owner).setIsEligible(vaultId, eligIds, true);
      await runVaultTests(
        nftx,
        asset,
        xToken,
        signers,
        vaultId,
        allNftIds,
        eligIds,
        false,
        false
      );
      _asset = asset;
    };

    ///////////////////
    // NFT-special-2 //
    ///////////////////

    const runNftSpecial2 = async () => {
      if (!_asset) {
        console.log("No _asset object...");
        return;
      }
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        _asset,
        "XToken-B2",
        allNftIds,
        false,
        false
      );
      const eligIds = getIntArray(0, 20).map((n) => n * 2 + 1);
      nftx.connect(owner).setNegateEligibility(vaultId, false);
      nftx.connect(owner).setIsEligible(vaultId, eligIds, true);
      await runVaultTests(
        nftx,
        asset,
        xToken,
        signers,
        vaultId,
        allNftIds,
        eligIds,
        false,
        false
      );
    };

    //////////////////
    // Punk-special //
    //////////////////

    const runPunkSpecial = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        cpm,
        "Punk-Special",
        allNftIds,
        true,
        false
      );
      const eligIds = getIntArray(0, 20).map((n) => n * 2);
      nftx.connect(owner).setNegateEligibility(vaultId, false);
      nftx.connect(owner).setIsEligible(vaultId, eligIds, true);
      await runVaultTests(
        nftx,
        asset,
        xToken,
        signers,
        vaultId,
        allNftIds,
        eligIds,
        true,
        false
      );
    };

    //////////////
    // D2 Vault //
    //////////////

    const runD2Vault = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        "Punk-BPT",
        "Punk",
        allNftIds,
        false,
        true
      );
      await runVaultTestsD2(nftx, asset, xToken, signers, vaultId);
    };

    ////////////////////////////////////////////////////////////////////
    // Run Vault Tests... //////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////
    
    await runNftBasic();
    await runPunkBasic();
    await runNftSpecial();
    await runNftSpecial2();
    await runPunkSpecial();
    await runD2Vault();
  });
});

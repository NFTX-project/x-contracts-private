const { expectRevert } = require("../utils/expectRevert");
const { runVaultTests } = require("./_runVaultTests");
const {
  getIntArray,
  initializeAssetTokenVault,
  setup,
  holdingsOf,
  approveAndMint,
  checkBalances,
  approveAndRedeem,
  cleanup,
} = require("./_helpers");

const bre = require("@nomiclabs/buidler");
const { ethers, upgrades } = bre;

const {
  getProxyFactory,
  getProxyAdminFactory,
} = require("@openzeppelin/buidler-upgrades/dist/proxy-factory");

describe("NFTX", function () {
  // return;
  this.timeout(0);
  it("Should run as expected", async function () {
    console.log("");
    ///////////////////////////////////////////////////////////////
    // Initialize NFTX ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////

    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const cpm = await Cpm.deploy();
    await cpm.deployed();

    const XStore = await ethers.getContractFactory("XStore");
    const xStore = await XStore.deploy();
    await xStore.deployed();

    const Nftx = await ethers.getContractFactory("NFTX");
    let nftx = await upgrades.deployProxy(Nftx, [cpm.address, xStore.address], {
      initializer: "initialize",
    });
    await nftx.deployed();
    await xStore.transferOwnership(nftx.address);

    const signers = await ethers.getSigners();
    const [owner, misc, alice, bob, carol, dave, eve, proxyAdmin] = signers;

    const allNftIds = getIntArray(0, 40);

    ///////////////
    // NFT-basic //
    ///////////////

    const runNftBasic = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        "NFT",
        "XToken",
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
        "NFT",
        "XToken",
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
        "XToken",
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
      await runVaultTests(
        nftx,
        asset,
        xToken,
        signers,
        vaultId,
        [],
        [],
        false,
        true
      );
    };

    //////////////////////
    // Contract upgrade //
    //////////////////////

    const runContractUpgrade = async () => {
      console.log("Testing: Contract upgrade...\n");

      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        "NFT",
        "XToken",
        allNftIds,
        false,
        false
      );
      const eligIds = getIntArray(0, 20);
      await setup(nftx, asset, signers, false, eligIds);
      const [aliceNFTs] = await holdingsOf(asset, eligIds, [alice], false);
      await approveAndMint(nftx, asset, aliceNFTs, alice, vaultId, 0, false);
      await checkBalances(nftx, asset, xToken, [alice], false);
      
      const NFTXv2 = await ethers.getContractFactory("NFTXv2");
      // nftx = await upgrades.upgradeProxy(nftx.address, NFTXv2);
      const nftxV2Address = await upgrades.prepareUpgrade(nftx.address, NFTXv2);
      await upgrades.admin.changeProxyAdmin(nftx.address, proxyAdmin._address);
      const ProxyFactory = await getProxyFactory(bre, owner);
      const proxy = ProxyFactory.attach(nftx.address);
      await proxy.connect(proxyAdmin).upgradeTo(nftxV2Address);
      nftx = NFTXv2.attach(nftx.address);

      const nftId = aliceNFTs[0];
      await nftx.transferERC721(vaultId, nftId, bob._address);
      await expectRevert(
        approveAndRedeem(nftx, xToken, aliceNFTs.length, alice, vaultId)
      );
      await asset.connect(bob).transferFrom(bob._address, nftx.address, nftId);
      await approveAndRedeem(nftx, xToken, aliceNFTs.length, alice, vaultId);

      await checkBalances(nftx, asset, xToken, [alice], false);
      await cleanup(nftx, asset, xToken, signers, vaultId, false, eligIds);
    };

    ////////////////////////////////////////////////////////////////////
    // Run Vault Tests... //////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////

    // await runNftBasic();
    // await runPunkBasic();
    // await runNftSpecial();
    // await runNftSpecial2();
    // await runPunkSpecial();
    // await runD2Vault();
    await runContractUpgrade();

    ////////////////////////////////////////////////////////////////////
    // Initialize XController... ///////////////////////////////////////
    ////////////////////////////////////////////////////////////////////

    /* const XController = await ethers.getContractFactory("XController");
    let xController = await upgrades.deployProxy(XController, [nftx.address], {
      initializer: "initialize",
    });
    await xController.deployed(); */

    const ProxyController = await ethers.getContractFactory(
      "ProxyController"
    );
    const proxyController = await upgrades.deployProxy(
      ProxyController, 
      [nftx.address], 
      { initializer: "initialize" },
    );

    ////////////////////////////////////////////////////////////////////
  });
});

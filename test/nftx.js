const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { expectRevert } = require("../utils/expectRevert");

const runVaultTests = require("./_runVaultTests");

const BASE = BigNumber.from(10).pow(18);
const UNIT = BASE.div(100);
const zeroAddress = "0x0000000000000000000000000000000000000000";

describe("NFTX", function () {
  this.timeout(0);
  it("Should run as expected", async function () {

    //////////////////////
    // Helper functions //
    //////////////////////

    const getAllIDs = () => {
      return getIntArray(0, 40);
    };

    const getIntArray = (firstElem, firstNonElem) => {
      const arr = [];
      for (let i = firstElem; i < firstNonElem; i++) {
        arr.push(i);
      }
      return arr;
    };

    const initializeAssetTokenVault = async (
      _nftx,
      _signers,
      assetNameOrExistingContract,
      xTokenName,
      isPV,
      isD2
    ) => {
      const [owner, misc, alice, bob, carol, dave, eve] = _signers;

      const XToken = await ethers.getContractFactory("XToken");
      const xToken = await XToken.deploy(xTokenName, xTokenName.toUpperCase());
      await xToken.deployed();
      await xToken.transferOwnership(_nftx.address);

      let asset;
      if (typeof assetNameOrExistingContract == "string") {
        let name = assetNameOrExistingContract;
        if (isD2) {
          asset = await Erc20.deploy(name, name.toUpperCase());
        } else {
          asset = await Erc721.deploy(name, name.toUpperCase());
        }
        await asset.deployed();
      } else {
        asset = assetNameOrExistingContract;
      }
      const response = await _nftx
        .connect(owner)
        .createVault(xToken.address, asset.address, isD2);
      const receipt = await response.wait(0);
      const vaultId = receipt.events[0].args[0].toString();
      await _nftx.connect(owner).finalizeVault(vaultId);
      if (isD2) {
        if (typeof assetNameOrExistingContract == "string") {
          asset.mint(misc._address, BASE.mul(1000));
        }
      } else {
        const nftIds = getAllIDs();
        await checkMintNFTs(asset, nftIds, misc, isPV);
      }
      return { asset, xToken, vaultId };
    };

    const checkMintNFTs = async (nft, nftIds, to, isPV) => {
      for (let i = 0; i < nftIds.length; i++) {
        if (isPV) {
          const owner = await nft.punkIndexToAddress(nftIds[i]);
          if (owner === zeroAddress) {
            await nft.setInitialOwner(to._address, nftIds[i]);
          }
        } else {
          try {
            await nft.ownerOf(nftIds[i]);
          } catch (err) {
            await nft.safeMint(to._address, nftIds[i]);
          }
        }
      }
    };

    const transferNFTs = async (
      _nftx,
      _nft,
      _nftIds,
      sender,
      recipient,
      isPV
    ) => {
      for (let i = 0; i < _nftIds.length; i++) {
        if (isPV) {
          await _nft
            .connect(sender)
            .transferPunk(recipient._address, _nftIds[i]);
        } else {
          await _nft
            .connect(sender)
            .transferFrom(sender._address, recipient._address, _nftIds[i]);
        }
      }
    };

    const setup = async (_nftx, _nft, _signers, _vaultId, isPV, eligIds) => {
      const [owner, misc, alice, bob, carol, dave, eve] = signers;
      await transferNFTs(_nftx, _nft, eligIds.slice(0, 8), misc, alice, isPV);
      await transferNFTs(_nftx, _nft, eligIds.slice(8, 16), misc, bob, isPV);
      await transferNFTs(_nftx, _nft, eligIds.slice(16, 19), misc, carol, isPV);
      await transferNFTs(_nftx, _nft, eligIds.slice(19, 20), misc, dave, isPV);
    };

    const cleanup = async (
      _nftx,
      _nft,
      _token,
      _signers,
      _vaultId,
      isPV,
      _eligIds
    ) => {
      const [owner, misc, alice, bob, carol, dave, eve] = signers;
      for (let i = 2; i < 7; i++) {
        const signer = _signers[i];
        const bal = (await _token.balanceOf(signer._address))
          .div(BASE)
          .toNumber();
        if (bal > 0) {
          await approveAndRedeem(_nftx, _token, bal, signer, _vaultId);
        }
      }
      for (let i = 0; i < 20; i++) {
        try {
          const nftId = _eligIds[i];
          let addr;
          if (isPV) {
            addr = await _nft.punkIndexToAddress(nftId);
          } else {
            addr = await _nft.ownerOf(nftId);
          }
          if (addr == misc._address) continue;
          const signer = _signers.find((s) => s._address == addr);
          if (isPV) {
            await _nft.connect(signer).transferPunk(misc._address, nftId);
          } else {
            await _nft
              .connect(signer)
              .transferFrom(signer._address, misc._address, nftId);
          }
        } catch (err) {
          console.log("catch:", i, err);
          break;
        }
      }
    };

    const holdingsOf = async (nft, nftIds, users, isPV, isD2) => {
      const lists = [];
      for (let i = 0; i < users.length; i++) {
        const user = users[i];
        const list = [];
        for (let _i = 0; _i < nftIds.length; _i++) {
          const id = nftIds[_i];
          const nftOwner = isPV
            ? await nft.punkIndexToAddress(id)
            : await nft.ownerOf(id);
          if (nftOwner === user._address) {
            list.push(id);
          }
        }
        lists.push(list);
      }
      return lists;
    };

    const checkBalances = async (nftx, nft, xToken, users, nftIds, isPV) => {
      let tokenAmount = BigNumber.from(0);
      for (let i = 0; i < users.length; i++) {
        const user = users[i];
        const bal = await xToken.balanceOf(user._address);
        tokenAmount = tokenAmount.add(bal);
      }
      const nftAmount = await nft.balanceOf(nftx.address);
      if (!nftAmount.mul(BASE).eq(tokenAmount)) {
        console.log(`
          ERROR: Balances do not match up
        `);
      }
    };

    const approveEach = async (_nft, _nftIds, signer, to, isPV) => {
      for (let i = 0; i < _nftIds.length; i++) {
        const nftId = _nftIds[i];
        if (isPV) {
          await _nft.connect(signer).offerPunkForSaleToAddress(nftId, 0, to);
        } else {
          await _nft.connect(signer).approve(to, nftId);
        }
      }
    };

    const approveAndMint = async (
      _nftx,
      _nft,
      _nftIds,
      signer,
      _vaultId,
      value,
      isPV
    ) => {
      await approveEach(_nft, _nftIds, signer, _nftx.address, isPV);
      await _nftx.connect(signer).mint(_vaultId, _nftIds, 0, { value: value });
    };

    const approveAndRedeem = async (
      _nftx,
      _token,
      amount,
      signer,
      _vaultId,
      value = 0
    ) => {
      await _token
        .connect(signer)
        .approve(_nftx.address, BASE.mul(amount).toString());
      await _nftx.connect(signer).redeem(_vaultId, amount, { value: value });
    };

    /////////////////////////////////////////////////////////
    // runVaultTests ////////////////////////////////////////
    /////////////////////////////////////////////////////////

    

    ///////////////////////////////////////////////////////////////
    // Initialize NFTX ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////

    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const cpm = await Cpm.deploy();
    await cpm.deployed();
    const Erc721 = await ethers.getContractFactory("ERC721");
    const Erc20 = await ethers.getContractFactory("D2Token");

    const Nftx = await ethers.getContractFactory("NFTX");
    const nftx = await Nftx.deploy(cpm.address);
    await nftx.deployed();

    const signers = await ethers.getSigners();
    const [owner, misc, alice, bob, carol, dave, eve] = signers;

    ///////////////
    // NFT-basic //
    ///////////////

    const runNftBasic = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx,
        signers,
        "NFT-A",
        "XToken-A",
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
        true,
        false
      );
      const eligIds = getIntArray(0, 20);
      await runVaultTests(nftx, asset, xToken, signers, vaultId, eligIds, true, false);
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
        true,
        false
      );
      const eligIds = getIntArray(0, 20).map((n) => n * 2);
      nftx.connect(owner).setNegateEligibility(vaultId, false);
      nftx.connect(owner).setIsEligible(vaultId, eligIds, true);
      await runVaultTests(nftx, asset, xToken, signers, vaultId, eligIds, true, false);
    };

    //////////////
    // D2 Vault //
    //////////////

    const runD2Vault = async () => {
      const { asset, xToken, vaultId } = await initializeAssetTokenVault(
        nftx, 
        signers, 
        'Punk-BPT', 
        'Punk', 
        false,
        true
      );
      // TODO:
    };

    ////////////////////////
    // Run Vault Tests... //
    ////////////////////////

    // await runNftBasic();
    // await runPunkBasic();
    // await runNftSpecial();
    // await runNftSpecial2();
    // await runPunkSpecial();
    await runD2Vault();
  });
});

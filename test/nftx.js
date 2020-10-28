const { expect } = require("chai");
const { BigNumber } = require("ethers");
// const { check } = require("yargs");
const { expectRevert } = require("../utils/expectRevert");

// const eligibleIds = (() => {
//   const arr = [];
//   for (let i = 0; i < 10000; i++) {
//     arr.push(i);
//   }
//   return arr;
// })();

const BASE = BigNumber.from(10).pow(18);
const UNIT = BASE.div(1000);

describe("NFTX", function () {
  this.timeout(0);
  it("Should run as expected", async function () {
    //////////////////////
    // Helper functions //
    //////////////////////

    const getIntArray = (firstElem, firstNonElem) => {
      const arr = [];
      for (let i = firstElem; i < firstNonElem; i++) {
        arr.push(i);
      }
      return arr;
    };

    const initializeNftTokenVault = async (
      _nftx,
      _signers,
      nftName,
      nftSymbol,
      tokenName,
      tokenSymbol
    ) => {
      const [owner, misc, alice, bob, carol, dave, eve] = _signers;
      const nft = await Erc721.deploy("Autoglyphs", "AUTOGLYPH");
      await nft.deployed();
      const XToken = await ethers.getContractFactory("XToken");

      const xToken = await XToken.deploy("Glyph", "GLYPH");
      await xToken.deployed();
      await xToken.transferOwnership(_nftx.address);
      const xVaultId = (
        await _nftx
          .connect(alice)
          .createVault(xToken.address, nft.address, false)
      ).value.toNumber();
      await _nftx.connect(alice).finalizeVault(xVaultId);
      const nftIds = getIntArray(0, 20);
      for (let i = 0; i < nftIds.length; i++) {
        await nft.safeMint(misc._address, nftIds[i]);
      }
      return { nft, xToken, xVaultId };
    };

    const transferNFTs = async (_nftx, _nft, _nftIds, sender, recipient) => {
      for (let i = 0; i < _nftIds.length; i++) {
        await _nft
          .connect(sender)
          .transferFrom(sender._address, recipient._address, _nftIds[i]);
      }
    };

    const setup = async (_nftx, _nft, _signers, _vaultId) => {
      const [owner, misc, alice, bob, carol, dave, eve] = signers;
      await transferNFTs(_nftx, _nft, getIntArray(0, 8), misc, alice);
      await transferNFTs(_nftx, _nft, getIntArray(8, 16), misc, bob);
      await transferNFTs(_nftx, _nft, getIntArray(16, 19), misc, carol);
      await transferNFTs(_nftx, _nft, getIntArray(19, 20), misc, dave);
    };

    const cleanup = async (_nftx, _nft, _token, _signers, _vaultId) => {
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
          const nftId = i;
          const addr = await _nft.ownerOf(nftId);
          if (addr == misc._address) continue;
          const signer = _signers.find((s) => s._address == addr);
          await _nft
            .connect(signer)
            .transferFrom(signer._address, misc._address, nftId);
        } catch (err) {
          console.log("catch:", i, err);
          break;
        }
      }
    };

    const holdingsOf = async (_nft, _nftIds, _users) => {
      const lists = [];
      for (let i = 0; i < _users.length; i++) {
        const user = _users[i];
        const list = [];
        for (let _i = 0; _i < _nftIds.length; _i++) {
          const id = _nftIds[_i];
          const nftOwner = await _nft.ownerOf(id);
          if (nftOwner === user._address) {
            list.push(id);
          }
        }
        lists.push(list);
      }
      return lists;
    };

    const approveEach = async (_nft, _nftIds, signer, to) => {
      for (let i = 0; i < _nftIds.length; i++) {
        const nftId = _nftIds[i];
        await _nft.connect(signer).approve(to, nftId);
      }
    };

    const approveAndMint = async (
      _nftx,
      _nft,
      _nftIds,
      signer,
      _vaultId,
      value = 0
    ) => {
      await approveEach(_nft, _nftIds, signer, _nftx.address);
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

    const runVaultTests = async (
      _nftx,
      _nft,
      _token,
      _signers,
      _vaultId,
      _nftIds
    ) => {
      const [owner, misc, alice, bob, carol, dave, eve] = _signers;

      //////////////////
      // mint, redeem //
      //////////////////

      await setup(_nftx, _nft, _signers, _vaultId);
      let [aliceNFTs, bobNFTs] = await holdingsOf(nft, nftIds, [alice, bob]);

      await approveAndMint(_nftx, _nft, aliceNFTs, alice, _vaultId);
      await approveAndMint(_nftx, _nft, bobNFTs, bob, _vaultId);
      await approveAndRedeem(_nftx, _token, aliceNFTs.length, alice, _vaultId);
      await approveAndRedeem(_nftx, _token, bobNFTs.length, bob, _vaultId);

      [aliceNFTs, bobNFTs] = await holdingsOf(_nft, _nftIds, [alice, bob]);
      console.log(aliceNFTs);
      console.log(bobNFTs);
      await cleanup(_nftx, _nft, _token, _signers, _vaultId);

      ///////////////////
      // mintAndRedeem //
      ///////////////////

      await setup(_nftx, _nft, _signers, _vaultId);
      [aliceNFTs, bobNFTs] = await holdingsOf(_nft, _nftIds, [alice, bob]);

      await approveAndMint(_nftx, _nft, aliceNFTs, alice, _vaultId);
      await approveEach(_nft, bobNFTs, bob, _nftx.address);
      await _nftx.connect(bob).mintAndRedeem(_vaultId, bobNFTs);

      [bobNFTs] = await holdingsOf(_nft, _nftIds, [bob]);
      console.log(bobNFTs);
      await cleanup(_nftx, _nft, _token, _signers, _vaultId);

      ////////////////////////
      // mintFees, burnFees //
      ////////////////////////

      await setup(_nftx, _nft, _signers, _vaultId);
      [aliceNFTs, bobNFTs] = await holdingsOf(_nft, _nftIds, [alice, bob]);
      await _nftx.connect(owner).setMintFees(_vaultId, UNIT.mul(5), UNIT);
      await _nftx.connect(owner).setBurnFees(_vaultId, UNIT.mul(5), UNIT);

      const amount = UNIT.mul(5).add(UNIT.mul(2));
      await expectRevert(
        approveAndMint(
          _nftx,
          _nft,
          aliceNFTs.slice(0, 3),
          alice,
          _vaultId,
          amount.sub(1)
        )
      );
      await approveAndMint(
        _nftx,
        _nft,
        aliceNFTs.slice(0, 3),
        alice,
        _vaultId,
        amount
      );
      await expectRevert(
        approveAndRedeem(_nftx, _token, 3, alice, _vaultId, amount.sub(1))
      );
      await approveAndRedeem(_nftx, _token, 3, alice, _vaultId, amount);

      await _nftx.connect(owner).setMintFees(_vaultId, 0, 0);
      await _nftx.connect(owner).setBurnFees(_vaultId, 0, 0);
      await cleanup(_nftx, _nft, _token, _signers, _vaultId);

      //////////////
      // dualFees //
      //////////////
    };

    /////////////////////
    // Initialize NFTX //
    /////////////////////

    const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
    const cpm = await Cpm.deploy();
    await cpm.deployed();
    const Erc721 = await ethers.getContractFactory("ERC721");

    const Nftx = await ethers.getContractFactory("NFTX");
    const nftx = await Nftx.deploy(cpm.address);
    await nftx.deployed();

    const signers = await ethers.getSigners();
    const [owner, misc, alice, bob, carol, dave, eve] = signers;

    ///////////////
    // NFT-basic //
    ///////////////

    const { nft, xToken, xVaultId } = await initializeNftTokenVault(
      nftx,
      signers,
      "Autoglyphs",
      "AGX",
      "Glyph",
      "GLYPH"
    );
    const nftIds = getIntArray(0, 20);
    await runVaultTests(nftx, nft, xToken, signers, xVaultId, nftIds);
  });
});

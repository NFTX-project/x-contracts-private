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
const UNIT = BASE.div(100);

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
      nftNameOrExistingContract,
      isPV,
      tokenName
    ) => {
      const [owner, misc, alice, bob, carol, dave, eve] = _signers;

      const XToken = await ethers.getContractFactory("XToken");
      const xToken = await XToken.deploy(tokenName, tokenName.toUpperCase());
      await xToken.deployed();
      await xToken.transferOwnership(_nftx.address);

      let nft;
      if (typeof nftNameOrExistingContract == "string") {
        let name = nftNameOrExistingContract;
        nft = await Erc721.deploy(name, name.toUpperCase());
        await nft.deployed();
      } else {
        nft = nftNameOrExistingContract;
      }
      const response = await _nftx
        .connect(owner)
        .createVault(xToken.address, nft.address, false);
      const receipt = await response.wait(0);
      const vaultId = receipt.events[0].args[0].toString();
      await _nftx.connect(owner).finalizeVault(vaultId);
      const nftIds = getIntArray(0, 40);
      await mintNFTs(nft, nftIds, misc, isPV);
      return { nft, xToken, vaultId };
    };

    const mintNFTs = async ( nft, nftIds, to, isPV ) => {
      for (let i = 0; i < nftIds.length; i++) {
        if (isPV) {
          await nft.setInitialOwner(to._address, nftIds[i]);
        } else {
          await nft.safeMint(to._address, nftIds[i]);
        }
      }
    }

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

    const holdingsOf = async (_nft, _nftIds, _users, isPV) => {
      const lists = [];
      for (let i = 0; i < _users.length; i++) {
        const user = _users[i];
        const list = [];
        for (let _i = 0; _i < _nftIds.length; _i++) {
          const id = _nftIds[_i];
          const nftOwner = isPV
            ? await _nft.punkIndexToAddress(id)
            : await _nft.ownerOf(id);
          if (nftOwner === user._address) {
            list.push(id);
          }
        }
        lists.push(list);
      }
      return lists;
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

    const runVaultTests = async (
      _nftx,
      _nft,
      _token,
      _signers,
      _vaultId,
      _eligIds,
      isPV
    ) => {
      const [owner, misc, alice, bob, carol, dave, eve] = _signers;

      //////////////////
      // mint, redeem //
      //////////////////

      const runMintRedeem = async () => {
        console.log("\nTesting: mint, redeem...\n");
        await setup(_nftx, _nft, _signers, _vaultId, isPV, _eligIds);
        let [aliceNFTs, bobNFTs] = await holdingsOf(
          _nft,
          _eligIds,
          [alice, bob],
          isPV
        );
        await approveAndMint(_nftx, _nft, aliceNFTs, alice, _vaultId, 0, isPV);
        await approveAndMint(_nftx, _nft, bobNFTs, bob, _vaultId, 0, isPV);
        await approveAndRedeem(
          _nftx,
          _token,
          aliceNFTs.length,
          alice,
          _vaultId
        );
        await approveAndRedeem(_nftx, _token, bobNFTs.length, bob, _vaultId);

        [aliceNFTs, bobNFTs] = await holdingsOf(
          _nft,
          _eligIds,
          [alice, bob],
          isPV
        );
        console.log(aliceNFTs);
        console.log(bobNFTs, "\n");
        await cleanup(_nftx, _nft, _token, _signers, _vaultId, isPV, _eligIds);
      };

      ///////////////////
      // mintAndRedeem //
      ///////////////////

      const runMintAndRedeem = async () => {
        console.log("Testing: mintAndRedeem...\n");
        await setup(_nftx, _nft, _signers, _vaultId, isPV, _eligIds);
        let [aliceNFTs, bobNFTs] = await holdingsOf(
          _nft,
          _eligIds,
          [alice, bob],
          isPV
        );
        await approveAndMint(_nftx, _nft, aliceNFTs, alice, _vaultId, 0, isPV);

        await approveEach(_nft, bobNFTs, bob, _nftx.address, isPV);
        await _nftx.connect(bob).mintAndRedeem(_vaultId, bobNFTs);

        [bobNFTs] = await holdingsOf(_nft, _eligIds, [bob], isPV);
        console.log(bobNFTs, "\n");
        await cleanup(_nftx, _nft, _token, _signers, _vaultId, isPV, _eligIds);
      };

      ////////////////////////
      // mintFees, burnFees //
      ////////////////////////

      const runMintFeesBurnFees = async () => {
        console.log("Testing: mintFees, burnFees...\n");
        await setup(_nftx, _nft, _signers, _vaultId, isPV, _eligIds);
        let [aliceNFTs, bobNFTs] = await holdingsOf(
          _nft,
          _eligIds,
          [alice, bob],
          isPV
        );
        await _nftx.connect(owner).setMintFees(_vaultId, UNIT.mul(5), UNIT);
        await _nftx.connect(owner).setBurnFees(_vaultId, UNIT.mul(5), UNIT);

        const n = aliceNFTs.length;
        let amount = UNIT.mul(5).add(UNIT.mul(n - 1));
        await expectRevert(
          approveAndMint(
            _nftx,
            _nft,
            aliceNFTs,
            alice,
            _vaultId,
            amount.sub(1),
            isPV
          )
        );
        await approveAndMint(
          _nftx,
          _nft,
          aliceNFTs,
          alice,
          _vaultId,
          amount,
          isPV
        );
        await expectRevert(
          approveAndRedeem(_nftx, _token, n, alice, _vaultId, amount.sub(1))
        );
        await approveAndRedeem(_nftx, _token, n, alice, _vaultId, amount);

        await _nftx.connect(owner).setMintFees(_vaultId, 0, 0);
        await _nftx.connect(owner).setBurnFees(_vaultId, 0, 0);
        await cleanup(_nftx, _nft, _token, _signers, _vaultId, isPV, _eligIds);
      };

      //////////////
      // dualFees //
      //////////////

      const runDualFees = async () => {
        console.log("Testing: dualFees...\n");
        await setup(_nftx, _nft, _signers, _vaultId, isPV, _eligIds);
        let [aliceNFTs, bobNFTs] = await holdingsOf(
          _nft,
          _eligIds,
          [alice, bob],
          isPV
        );
        await _nftx.connect(owner).setDualFees(_vaultId, UNIT.mul(5), UNIT);
        await approveAndMint(_nftx, _nft, aliceNFTs, alice, _vaultId, 0, isPV);

        await approveEach(_nft, bobNFTs, bob, _nftx.address, isPV);
        let amount = UNIT.mul(5).add(UNIT.mul(bobNFTs.length - 1));
        await expectRevert(
          _nftx
            .connect(bob)
            .mintAndRedeem(_vaultId, bobNFTs, { value: amount.sub(1) })
        );
        await _nftx
          .connect(bob)
          .mintAndRedeem(_vaultId, bobNFTs, { value: amount });

        await _nftx.connect(owner).setDualFees(_vaultId, 0, 0);
        await cleanup(_nftx, _nft, _token, _signers, _vaultId, isPV, _eligIds);
      };

      ////////////////////
      // supplierBounty //
      ////////////////////

      const runSupplierBounty = async () => {
        console.log("Testing: supplierBounty...\n");
        await setup(_nftx, _nft, _signers, _vaultId, isPV, _eligIds);
        let [aliceNFTs, bobNFTs] = await holdingsOf(
          _nft,
          _eligIds,
          [alice, bob],
          isPV
        );
        await _nftx
          .connect(owner)
          .depositETH(_vaultId, { value: UNIT.mul(100) });
        await _nftx.connect(owner).setSupplierBounty(_vaultId, UNIT.mul(10), 5);

        let nftxBal1 = BigNumber.from(await web3.eth.getBalance(_nftx.address));
        let aliceBal1 = BigNumber.from(
          await web3.eth.getBalance(alice._address)
        );
        await approveAndMint(_nftx, _nft, aliceNFTs, alice, _vaultId, 0, isPV);
        let nftxBal2 = BigNumber.from(await web3.eth.getBalance(_nftx.address));
        let aliceBal2 = BigNumber.from(
          await web3.eth.getBalance(alice._address)
        );
        expect(nftxBal2.toString()).to.equal(
          nftxBal1.sub(UNIT.mul(10 + 8 + 6 + 4 + 2)).toString()
        );
        expect(aliceBal2.gt(aliceBal1)).to.equal(true);
        await approveAndRedeem(
          _nftx,
          _token,
          aliceNFTs.length,
          alice,
          _vaultId,
          UNIT.mul(10 + 8 + 6 + 4 + 2).toString()
        );
        let nftxBal3 = BigNumber.from(await web3.eth.getBalance(_nftx.address));
        let aliceBal3 = BigNumber.from(
          await web3.eth.getBalance(alice._address)
        );
        expect(nftxBal3.toString()).to.equal(nftxBal1.toString());
        expect(aliceBal3.lt(aliceBal2)).to.equal(true);

        await _nftx.connect(owner).setSupplierBounty(_vaultId, 0, 0);
        await cleanup(_nftx, _nft, _token, _signers, _vaultId, isPV, _eligIds);
      };

      ////////////////
      // isEligible //
      ////////////////

      const runIsEligible = async () => {
        console.log("Testing: isEligible...\n");
        await setup(_nftx, _nft, _signers, _vaultId, isPV, _eligIds);
        let [aliceNFTs] = await holdingsOf(_nft, _eligIds, [alice], isPV);
        let nftIds = _eligIds.slice(0, 2).map((n) => n + 1)
        await mintNFTs(_nft, nftIds, alice, isPV)
        await approveAndMint(
          _nftx,
          _nft,
          nftIds,
          alice,
          _vaultId,
          0,
          isPV
        );

        await approveAndMint(
          _nftx,
          _nft,
          _eligIds.slice(0, 2),
          alice,
          _vaultId,
          0,
          isPV
        );

        await cleanup(_nftx, _nft, _token, _signers, _vaultId, isPV, _eligIds);
      };

      //////////////////////////
      // Run Feature Tests... //
      //////////////////////////

      // await runMintRedeem();
      // await runMintAndRedeem();
      // await runMintFeesBurnFees();
      // await runDualFees();
      // await runSupplierBounty();
      if (_eligIds[1] - _eligIds[0] > 1) {
        await runIsEligible();
      }
    };

    ///////////////////////////////////////////////////////////////
    // Initialize NFTX ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////

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

    const runNftBasic = async () => {
      const { nft, xToken, vaultId } = await initializeNftTokenVault(
        nftx,
        signers,
        "Autoglyphs",
        false,
        "Glyph"
      );
      const eligIds = getIntArray(0, 20);
      await runVaultTests(nftx, nft, xToken, signers, vaultId, eligIds, false);
    };

    ////////////////
    // Punk-basic //
    ////////////////

    const runPunkBasic = async () => {
      const { nft, xToken, vaultId } = await initializeNftTokenVault(
        nftx,
        signers,
        cpm,
        true,
        "Punk-Basic"
      );
      const eligIds = getIntArray(0, 20);
      await runVaultTests(nftx, nft, xToken, signers, vaultId, eligIds, true);
    };

    /////////////////
    // NFT-special //
    /////////////////

    const runNftSpecial = async () => {
      const { nft, xToken, vaultId } = await initializeNftTokenVault(
        nftx,
        signers,
        "Autoglyphs",
        false,
        "Glyph"
      );
      const eligIds = getIntArray(0, 20).map((n) => n * 2);
      nftx.connect(owner).setNegateEligibility(vaultId, false);
      nftx.connect(owner).setIsEligible(vaultId, eligIds, true);
      await runVaultTests(nftx, nft, xToken, signers, vaultId, eligIds, false);
    };

    ////////////////////////
    // Run Vault Tests... //
    ////////////////////////

    // await runNftBasic();
    // await runPunkBasic();
    await runNftSpecial();
  });
});

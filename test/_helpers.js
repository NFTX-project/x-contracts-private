const { BigNumber } = require("ethers");

const BASE = BigNumber.from(10).pow(18);
const UNIT = BASE.div(100);
const zeroAddress = "0x0000000000000000000000000000000000000000";

const getIntArray = (firstElem, firstNonElem) => {
  const arr = [];
  for (let i = firstElem; i < firstNonElem; i++) {
    arr.push(i);
  }
  return arr;
};

const initializeAssetTokenVault = async (
  nftx,
  signers,
  assetNameOrExistingContract,
  xTokenName,
  idsToMint,
  isPV,
  isD2
) => {
  const [owner, misc, alice, bob, carol, dave, eve] = signers;

  const XToken = await ethers.getContractFactory("XToken");
  const xToken = await XToken.deploy(xTokenName, xTokenName.toUpperCase());
  await xToken.deployed();
  await xToken.transferOwnership(nftx.address);

  let asset;
  if (typeof assetNameOrExistingContract == "string") {
    let name = assetNameOrExistingContract;
    if (isD2) {
      const Erc20 = await ethers.getContractFactory("D2Token");
      asset = await Erc20.deploy(name, name.toUpperCase());
    } else {
      const Erc721 = await ethers.getContractFactory("ERC721");
      asset = await Erc721.deploy(name, name.toUpperCase());
    }
    await asset.deployed();
  } else {
    asset = assetNameOrExistingContract;
  }
  const response = await nftx
    .connect(owner)
    .createVault(xToken.address, asset.address, isD2);
  const receipt = await response.wait(0);
  const vaultId = receipt.events[0].args[0].toString();
  await nftx.connect(owner).finalizeVault(vaultId);
  if (isD2) {
    if (typeof assetNameOrExistingContract == "string") {
      asset.mint(misc._address, BASE.mul(1000));
    }
  } else {
    await checkMintNFTs(asset, idsToMint, misc, isPV);
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

const transferNFTs = async (nftx, nft, nftIds, sender, recipient, isPV) => {
  for (let i = 0; i < nftIds.length; i++) {
    if (isPV) {
      await nft.connect(sender).transferPunk(recipient._address, nftIds[i]);
    } else {
      await nft
        .connect(sender)
        .transferFrom(sender._address, recipient._address, nftIds[i]);
    }
  }
};

const setup = async (nftx, nft, signers, vaultId, isPV, eligIds) => {
  const [owner, misc, alice, bob, carol, dave, eve] = signers;
  await transferNFTs(nftx, nft, eligIds.slice(0, 8), misc, alice, isPV);
  await transferNFTs(nftx, nft, eligIds.slice(8, 16), misc, bob, isPV);
  await transferNFTs(nftx, nft, eligIds.slice(16, 19), misc, carol, isPV);
  await transferNFTs(nftx, nft, eligIds.slice(19, 20), misc, dave, isPV);
};

const cleanup = async (nftx, nft, token, signers, vaultId, isPV, eligIds) => {
  const [owner, misc, alice, bob, carol, dave, eve] = signers;
  for (let i = 2; i < 7; i++) {
    const signer = signers[i];
    const bal = (await token.balanceOf(signer._address)).div(BASE).toNumber();
    if (bal > 0) {
      await approveAndRedeem(nftx, token, bal, signer, vaultId);
    }
  }
  for (let i = 0; i < 20; i++) {
    try {
      const nftId = eligIds[i];
      let addr;
      if (isPV) {
        addr = await nft.punkIndexToAddress(nftId);
      } else {
        addr = await nft.ownerOf(nftId);
      }
      if (addr == misc._address) continue;
      const signer = signers.find((s) => s._address == addr);
      if (isPV) {
        await nft.connect(signer).transferPunk(misc._address, nftId);
      } else {
        await nft
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

const approveEach = async (nft, nftIds, signer, to, isPV) => {
  for (let i = 0; i < nftIds.length; i++) {
    const nftId = nftIds[i];
    if (isPV) {
      await nft.connect(signer).offerPunkForSaleToAddress(nftId, 0, to);
    } else {
      await nft.connect(signer).approve(to, nftId);
    }
  }
};

const approveAndMint = async (
  nftx,
  nft,
  nftIds,
  signer,
  vaultId,
  value,
  isPV
) => {
  await approveEach(nft, nftIds, signer, nftx.address, isPV);
  await nftx.connect(signer).mint(vaultId, nftIds, 0, { value: value });
};

const approveAndRedeem = async (
  nftx,
  token,
  amount,
  signer,
  vaultId,
  value = 0
) => {
  await token
    .connect(signer)
    .approve(nftx.address, BASE.mul(amount).toString());
  await nftx.connect(signer).redeem(vaultId, amount, { value: value });
};

exports.getIntArray = getIntArray;
exports.initializeAssetTokenVault = initializeAssetTokenVault;
exports.checkMintNFTs = checkMintNFTs;
exports.transferNFTs = transferNFTs;
exports.setup = setup;
exports.cleanup = cleanup;
exports.holdingsOf = holdingsOf;
exports.checkBalances = checkBalances;
exports.approveEach = approveEach;
exports.approveAndMint = approveAndMint;
exports.approveAndRedeem = approveAndRedeem;

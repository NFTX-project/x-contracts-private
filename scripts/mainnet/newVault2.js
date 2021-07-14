const { ethers, upgrades } = require("hardhat");

const addresses = require("../../addresses/mainnet.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const XToken = await ethers.getContractFactory("XToken");
  const xStore = await ethers.getContractAt("XStore", addresses.xStore);

  const nftx = await ethers.getContractAt("NFTXv4", addresses.nftx);

  /* const fundToken = await XToken.deploy(
    "Variant Plan F01Y20",
    "VARIANT-DAVIS",
    addresses.nftx
  );
  await fundToken.deployed();
  console.log(`Token deployed to ${fundToken.address}`); */

  const fundTokenAddress = "0xb547faf8bd5a52b1fe4ce5d740bdfb396140eb08";
  const artBlocksAddress = "0xa7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd270";

  await nftx.createVault(fundTokenAddress, artBlocksAddress, false);

  console.log(`Vault created`);

  /* await new Promise((resolve) => setTimeout(() => resolve(), 6000));
  console.log("continuing..."); */

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

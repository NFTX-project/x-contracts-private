const { ethers, upgrades } = require("hardhat");

const addresses = require("../../addresses/mainnet.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Using the account:", await deployer.getAddress());

  console.log("Account balance:", (await deployer.getBalance()).toString());

  /* const xStore = await ethers.getContractAt("XStore", addresses.xStore);
  const nftx = await ethers.getContractAt("NFTX", addresses.nftx); */

  const proxyCont = await ethers.getContractAt(
    "ProxyController",
    addresses.proxyController
  );

  const NFTXv11 = await ethers.getContractFactory("NFTXv11");

  // const nftxv7Address = await upgrades.prepareUpgrade(addresses.nftx, NFTXv7);

  const nftxv11 = await NFTXv11.deploy();

  console.log("NFTXv11 Implementation:", nftxv11.address);

  console.log(
    "\nNow go and call proxyController.upgradeProxyTo(...) from Aragon Agent\n"
  );

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

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

  console.log("A");
  const NFTXv6 = await ethers.getContractFactory("NFTXv6");
  console.log("B");
  const nftxV6Address = await upgrades.prepareUpgrade(addresses.nftx, NFTXv6);

  console.log("NFTXv6 Implementation:", nftxV6Address);

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

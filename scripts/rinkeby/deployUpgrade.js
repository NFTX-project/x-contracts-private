const { ethers, upgrades } = require("hardhat");

const addresses = require("../../addresses/rinkeby.json");

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

  const NFTXv2 = await ethers.getContractFactory("NFTXv2");

  const nftxV2Address = await upgrades.prepareUpgrade(addresses.nftx, NFTXv2);

  console.log("NFTXv2 Implementation:", nftxV2Address);

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

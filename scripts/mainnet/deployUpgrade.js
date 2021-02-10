const { ethers, upgrades } = require("@nomiclabs/buidler");

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

  const NFTXv5 = await ethers.getContractFactory("NFTXv5");

  const nftxV5Address = await upgrades.prepareUpgrade(addresses.nftx, NFTXv5);

  console.log("NFTXv5 Implementation:", nftxV5Address);

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
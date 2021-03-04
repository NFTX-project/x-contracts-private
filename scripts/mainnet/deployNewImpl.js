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

  const NFTXv6 = await ethers.getContractFactory("NFTXv6");

  // const nftxV6Address = await upgrades.prepareUpgrade(addresses.nftx, NFTXv6);

  const nftxv6 = await NFTXv6.deploy();

  console.log("NFTXv6 Implementation:", nftxv6.address);

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

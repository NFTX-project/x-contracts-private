// import zombidIds from "../data/zombies";

const { ethers, upgrades } = require("@nomiclabs/buidler");

// const zeroAddress = "0x0000000000000000000000000000000000000000";

const rinkebyDaoAddress = "0xeddb1b92b9ad55a5bb1dcc22c23e7839cd3dc99c";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  /* const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
  const cpm = await Cpm.deploy();
  await cpm.deployed();
  console.log("CPM address:", cpm.address); */
  const XStore = await ethers.getContractFactory("XStore");
  const xStore = await XStore.deploy();
  await xStore.deployed();
  console.log("XStore address:", xStore.address);

  const Nftx = await ethers.getContractFactory("NFTX");
  let nftx = await upgrades.deployProxy(Nftx, [xStore.address], {
    initializer: "initialize",
  });
  await nftx.deployed();
  console.log("NFTX proxy address:", nftx.address);

  const ProxyController = await ethers.getContractFactory("ProxyController");
  const proxyController = await ProxyController.deploy(nftx.address);
  await proxyController.deployed();
  console.log("ProxyController address:", proxyController.address);

  // let proxyAdminAddr = await proxyController.getAdmin();
  // console.log("Proxy admin:", proxyAdminAddr);

  await upgrades.admin.changeProxyAdmin(nftx.address, proxyController.address);
  console.log("Updated NFTX proxy admin");

  // proxyAdminAddr = await proxyController.getAdmin();
  // console.log("Proxy admin:", proxyAdminAddr);

  /* await proxyController.updateImplAddress();
  const implAddress = await proxyController.implAddress();
  console.log("NFTX implementation address:", implAddress); */

  /* const NftxV2 = await ethers.getContractFactory("NFTXv2");
  console.log("Preparing upgrade...");
  const nftxV2Address = await upgrades.prepareUpgrade(nftx.address, NftxV2);
  console.log("NftxV2 at:", nftxV2Address); */

  await proxyController.transferOwnership(rinkebyDaoAddress);
  console.log("Updated ProxyController owner");

  await xStore.transferOwnership(nftx.address);
  console.log("Updated XStore owner");

  await nftx.transferOwnership(rinkebyDaoAddress);
  console.log("Updated NFTX owner");

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

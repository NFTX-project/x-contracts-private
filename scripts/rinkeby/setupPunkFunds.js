// import zombidIds from "../data/zombies";

const { ethers, upgrades } = require("@nomiclabs/buidler");

// const zeroAddress = "0x0000000000000000000000000000000000000000";

const addresses = require("../../addresses/rinkeby.json");

const XStore = require('../../artifacts/XStore.json');
const Nftx = require('../../artifacts/NFTX.json');


async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const xStore = new ethers.Contract(addresses.xStore, XStore.abi, deployer);
  const nftx = new ethers.Contract(addresses.nftx, Nftx.abi, deployer);

  const XToken = await ethers.getContractFactory("XToken");

  const funds = [
    { ticker: "PUNK-BASIC" },
    { ticker: "PUNK-ATTR-4" },
    { ticker: "PUNK-ATTR-5" },
    { ticker: "PUNK-ZOMBIE" },
    { ticker: "KITTY-GEN-0" },
    { ticker: "KITTY-GEN-FAST" },
    { ticker: "KITTY-FANCY" },
    { ticker: "KITTY-FOUNDER" },
    { ticker: "AXIE-ORIGIN" },
    { ticker: "AXIE-MYSTIC-1" },
    { ticker: "AXIE-MYSTIC-2" },
    { ticker: "AVASTR-RANK-25" },
    { ticker: "AVASTR-RANK-50" },
    { ticker: "AVASTR-RANK-75" },
    { ticker: "GLYPH" },
    { ticker: "JOY" },
  ];

  for (let i = 0; i < funds.length; i++) {
    const fund = funds[i];
    const fundToken = await XToken.deploy(fund.ticker.toLowerCase(), fund.ticker, addresses.nftx);
    await fundToken.deployed();
    console.log(`${fund.ticker} deployed to ${fundToken.address}`);
    funds[i].tokenAddress = fundToken.address;
  }



  // const xToken = await XToken.deploy(name, symbol, addresses.nftx)

  await nftx.createVault(addresses)


  /* 
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

  await proxyController.updateImplAddress();
  const implAddress = await proxyController.implAddress();
  console.log("NFTX implementation address:", implAddress);

  /* await nftx.transferOwnership(rinkebyDaoAddress);
  console.log("Updated NFTX owner"); */ */

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

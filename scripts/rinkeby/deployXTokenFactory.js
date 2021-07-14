const { ethers, upgrades } = require("hardhat");

const addresses = require("../../addresses/rinkeby.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const XTokenClonable = await ethers.getContractFactory("XTokenClonable");
  const xTokenClonable = await XTokenClonable.deploy();

  await xTokenClonable.deployed();
  console.log("xtokenclonable deployed at", xTokenClonable.address);
  await xTokenClonable.initialize("Template Token", "TEMPLATE", {
    gasLimit: "9500000",
  });
  console.log("xtokenclonable initialized");

  const XTokenFactory = await ethers.getContractFactory("XTokenFactory");
  const xTokenFactory = await XTokenFactory.deploy(xTokenClonable.address);
  await xTokenFactory.deployed();
  console.log("xtokenfactory deployed at", xTokenFactory.address);
  await xTokenFactory.transferOwnership(addresses.nftx);

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

const { ethers, upgrades } = require("hardhat");

const addresses = require("../../addresses/rinkeby.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const XBounties = await ethers.getContractFactory("XBounties");
  const xBounties = await XBounties.deploy(
    addresses.tokenApp,
    addresses.dao,
    addresses.nftxToken,
    addresses.xStore
  );
  await xBounties.deployed();
  console.log("XBounties address:", xBounties.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

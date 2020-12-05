const { ethers, upgrades } = require("@nomiclabs/buidler");

const addresses = require("../../addresses/rinkeby.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const XToken = await ethers.getContractFactory("XToken");
  const xStore = await ethers.getContractAt("XStore", addresses.xStore);

  const nftx = await ethers.getContractAt("NFTX", addresses.nftx);

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

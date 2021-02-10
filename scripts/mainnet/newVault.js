const { ethers, upgrades } = require("@nomiclabs/buidler");

const addresses = require("../../addresses/mainnet.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const hashmaskAddress = "0xC2C747E0F7004F9E8817Db2ca4997657a7746928";

  const XToken = await ethers.getContractFactory("XToken");

  const fundToken = await XToken.deploy("Cubes", "CUBES", addresses.nftx);
  await fundToken.deployed();
  console.log(`Token deployed to ${fundToken.address}`);

  // const xStore = await ethers.getContractAt("XStore", addresses.xStore);

  // const nftx = await ethers.getContractAt("NFTX", addresses.nftx);

  // await nftx.createVault(fundToken.address, hashmaskAddress, false);

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

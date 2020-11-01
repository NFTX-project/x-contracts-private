// import zombidIds from "../data/zombies";

const { upgrades } = require("@nomiclabs/buidler");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Cpm = await ethers.getContractFactory("CryptoPunksMarket");
  const cpm = await Cpm.deploy();
  await cpm.deployed();

  const Nftx = await ethers.getContractFactory("NFTX");
  const nftx = await upgrades.deployProxy(Nftx, [cpm.address], {
    initializer: "initialize",
  });
  await nftx.deployed();

  console.log("CPM address:", cpm.address);
  console.log("XToken address:", nftx.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const CryptoPunksMarket = await ethers.getContractFactory(
    "CryptoPunksMarket"
  );
  const PunkToken = await ethers.getContractFactory("PunkToken");
  const PunkVault = await ethers.getContractFactory("PunkVault");

  const cpm = await CryptoPunksMarket.deploy();
  await cpm.deployed();

  const punkToken = await PunkToken.deploy("PunkToken", "PUNK");
  await punkToken.deployed();

  const punkVault = await PunkVault.deploy(punkToken.address, cpm.address);
  await punkVault.deployed();

  await punkToken.transferOwnership(punkVault.address);
  await punkVault.increaseSecurityLevel();
  await punkVault.transferOwnership(
    "0x425d33d6bcb86Ece121395133Ed7f5c167F5Fea4"
  );

  console.log("CPM address:", cpm.address);
  console.log("PunkToken address:", punkToken.address);
  console.log("PunkVault address:", punkVault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const cryptoPunksAddress = "0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB";

  const PunkToken = await ethers.getContractFactory("PunkToken");
  const PunkVault = await ethers.getContractFactory("PunkVault");

  const punkToken = await PunkToken.deploy("Punk", "PUNK");
  await punkToken.deployed();

  const punkVault = await PunkVault.deploy(
    punkToken.address,
    cryptoPunksAddress
  );
  await punkVault.deployed();

  await punkToken.transferOwnership(punkVault.address);
  await punkVault.transferOwnership(
    "0x8F217D5cCCd08fD9dCe24D6d42AbA2BB4fF4785B"
  );
  // await punkVault.setReverseLink();
  // await punkVault.increaseSecurityLevel();

  console.log("PunkToken address:", punkToken.address);
  console.log("PunkVault address:", punkVault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

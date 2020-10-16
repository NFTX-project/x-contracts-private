import zombidIds from "../data/zombies";

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
  await punkVault.transferOwnership(
    "0x2435eDc484701613A1f22C18EB8fAdCaD6C5F288"
  );

  // await punkVault.setReverseLink();

  /* await punkVault.initiateUnlock(2);
  await punkVault.setEligibilities(
    zombieIds(),
    true
  );
 */

  // await punkVault.increaseSecurityLevel();

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

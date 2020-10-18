import zombidIds from "../data/zombies";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const CryptoXsMarket = await ethers.getContractFactory("CryptoXsMarket");
  const XToken = await ethers.getContractFactory("XToken");
  const XVault = await ethers.getContractFactory("XVault");

  const cpm = await CryptoXsMarket.deploy();
  await cpm.deployed();

  const xToken = await XToken.deploy("XToken", "PUNK");
  await xToken.deployed();

  const xVault = await XVault.deploy(xToken.address, cpm.address);
  await xVault.deployed();

  await xToken.transferOwnership(xVault.address);
  await xVault.transferOwnership("0x2435eDc484701613A1f22C18EB8fAdCaD6C5F288");

  // await xVault.setReverseLink();

  /* await xVault.initiateUnlock(2);
  await xVault.setEligibilities(
    zombieIds(),
    true
  );
 */

  // await xVault.increaseSecurityLevel();

  console.log("CPM address:", cpm.address);
  console.log("XToken address:", xToken.address);
  console.log("XVault address:", xVault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

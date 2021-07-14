const { ethers, upgrades } = require("hardhat");

const addresses = require("../../addresses/mainnet.json");

const punkFemaleIds = require("../../data/punk/punkFemale.json");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const xStore = await ethers.getContractAt("XStore", addresses.xStore);
  const nftx = await ethers.getContractAt("NFTX", addresses.nftx);

  const data = [
    {
      vaultId: 4,
    },
    {
      vaultId: 5,
    },
    {
      vaultId: 6,
    },
    {
      vaultId: 7,
    },
    {
      vaultId: 8,
    },
    {
      vaultId: 10,
    },
    {
      vaultId: 11,
    },
    {
      vaultId: 12,
    },
    {
      vaultId: 14,
    },
  ];

  for (let i = 0; i < data.length; i++) {
    const { vaultId } = data[i];
    /* let j = 0;
    while (j < ids.length) {
      let k = Math.min(j + 150, ids.length);
      const nftIds = ids.slice(j, k);
      console.log(`i: ${i}, j: ${j}, k: ${k}\n`);
      await nftx.setIsEligible(vaultId, nftIds, 0);
      j = k;
    } */
    await nftx.setAllowMintRequests(vaultId, true);
    console.log(`Vault ${vaultId} mint allowed\n`);
  }

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

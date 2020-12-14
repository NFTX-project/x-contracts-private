const { ethers, upgrades } = require("@nomiclabs/buidler");

const addresses = require("../../addresses/mainnet.json");

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

  const funds = [
    {
      ticker: "PUNK-FEMALE",
      name: "Punk-Female",
      asset: "cryptopunks",
      negateElig: false,
    },
  ];

  for (let i = 0; i < funds.length; i++) {
    const fund = funds[i];
    const fundToken = await XToken.deploy(
      fund.name,
      fund.ticker,
      addresses.nftx
    );
    await fundToken.deployed();
    console.log(`${fund.ticker} deployed to ${fundToken.address}`);
    funds[i].tokenAddress = fundToken.address;

    await nftx.createVault(fund.tokenAddress, addresses[fund.asset], false);
    console.log(`Vault created: ${fund.ticker}`);

    await new Promise((resolve) => setTimeout(() => resolve(), 6000));
    console.log("continuing...");

    if (fund.flipEligOnRedeem) {
      await nftx.setFlipEligOnRedeem(i, true, {
        gasLimit: "9500000",
      });
      console.log(`${fund.ticker} flipEligOnRedeem set to true`);

      await new Promise((resolve) => setTimeout(() => resolve(), 6000));
      console.log("continuing...");
    }
    if (fund.negateElig == false) {
      await nftx.setNegateEligibility(i, false, {
        gasLimit: "9500000",
      });
      console.log(`${fund.ticker} negateEligibility set to false`);

      await new Promise((resolve) => setTimeout(() => resolve(), 6000));
      console.log("continuing...");
    } else {
      await nftx.finalizeVault(i, {
        gasLimit: "9500000",
      });
      console.log(`${fund.ticker} finalized`);

      await new Promise((resolve) => setTimeout(() => resolve(), 6000));
      console.log("continuing...");
    }
    console.log("");
  }

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

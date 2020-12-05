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

  const funds = [
    { ticker: "PUNK-BASIC", asset: "cryptopunks" },
    { ticker: "PUNK-ATTR-4", asset: "cryptopunks" },
    { ticker: "PUNK-ATTR-5", asset: "cryptopunks" },
    { ticker: "PUNK-ZOMBIE", asset: "cryptopunks" },
    { ticker: "GLYPH", asset: "autoglyphs" },
    { ticker: "KITTY-GEN-0", asset: "cryptokitties" },
    { ticker: "KITTY-GEN-0-FAST", asset: "cryptokitties" },
    { ticker: "KITTY-FANCY", asset: "cryptokitties" },
    { ticker: "KITTY-FOUNDER", asset: "cryptokitties" },
    { ticker: "AXIE-ORIGIN", asset: "axies" },
    { ticker: "AXIE-MYSTIC-1", asset: "axies" },
    { ticker: "AXIE-MYSTIC-2", asset: "axies" },
    { ticker: "JOY", asset: "joys" },
    { ticker: "AVASTR-RANK-25", asset: "avastars" },
    { ticker: "AVASTR-RANK-50", asset: "avastas" },
    { ticker: "AVASTR-RANK-75", asset: "avastars" },
  ];

  for (let i = 0; i < funds.length; i++) {
    const fund = funds[i];
    const fundToken = await XToken.deploy(
      fund.ticker.toLowerCase(),
      fund.ticker,
      addresses.nftx
    );
    await fundToken.deployed();
    console.log(`${fund.ticker} deployed to ${fundToken.address}`);
    funds[i].tokenAddress = fundToken.address;
  }

  for (let i = 0; i < funds.length; i++) {
    const fund = funds[i];
    await nftx.createVault(fund.tokenAddress, addresses[fund.asset], false);
    console.log(`Vault created: ${fund.ticker}`);
  }

  const numVaults = await xStore.vaultsLength();
  console.log("Num vaults:", numVaults);

  console.log("-- DONE --");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

require("dotenv").config();
require("@nomiclabs/buidler-waffle");
require("@nomiclabs/buidler-web3");
require("@nomiclabs/buidler-ethers");
require("@openzeppelin/buidler-upgrades");
// require("buidler-contract-sizer");

const oneGwei = 1000000000;

module.exports = {
  networks: {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`${process.env.PRIVATE_KEY}`],
      /* gasPrice: 195 * oneGwei, */
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`${process.env.PRIVATE_KEY}`],
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`${process.env.PRIVATE_KEY}`],
      /* gasPrice: 5000000000, */
      timeout: 30000,
    },
  },
  solidity: {
    version: "0.6.8",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
  },
};

require("dotenv").config();
usePlugin("@nomiclabs/buidler-waffle");
usePlugin("@nomiclabs/buidler-web3");

module.exports = {
  networks: {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
  solc: {
    version: "0.6.8",
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};

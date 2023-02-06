require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter")
require('hardhat-abi-exporter');
require('dotenv').config();
const { utils } = require("ethers");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});


const accounts = {
  mnemonic: process.env.MNEMONIC,
  // accountsBalance: "990000000000000000000",
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */


module.exports = {
  defaultNetwork: 'hardhat',
  mocha: {
    timeout: 99999999999
  },
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: "USD",
    enabled: false
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      default: 1,
    },
  },
  networks: {
    hardhat: {
      gasPrice: parseInt(utils.parseUnits("20", "gwei")),
      allowUnlimitedContractSize: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 9999,
        },
      },
      initialBaseFeePerGas: 0,
      accounts,
    },
    polygon: {
      url: "https://rpc-mainnet.maticvigil.com",
      accounts: [process.env.DEPLOY_PRIV_KEY],
      gasPrice: parseInt(utils.parseUnits("50", "gwei"))
    },
    polygonMumbai: {
      // url: "https://rpc-mumbai.matic.today",
      url: "https://matic-mumbai.chainstacklabs.com",
      
      accounts: [process.env.DEPLOY_PRIV_KEY]
    },


    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts,
      chainId: 1,
      live: false,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
      saveDeployments: true
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts,
      chainId: 4,
      live: false,
      saveDeployments: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
      tags: ["test"],
      gasPrice: 5000000000,
      gasMultiplier: 2,
    },
  },

  paths: {
    deploy: "deploy",
    deployments: "deployments",
    sources: "./contracts",
    artifacts: "./artifacts",
    cache: "./cache",
    tests: "./test"
  },

  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
    // {
    //   polygon: process.env.POLYGONSCAN_API_KEY,
    //   polygonMumbai: process.env.POLYGONSCAN_API_KEY,
    //   rinkeby: "YOUR_ETHERSCAN_API_KEY",
    //   mainnet: "YOUR_ETHERSCAN_API_KEY",
    // }
  },

  abiExporter: [
    {
      path: './abi/pretty',
      pretty: true,
    },
    {
      path: './abi/ugly',
      pretty: false,
    },
  ]

};

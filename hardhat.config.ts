import { config as dotenvConfig } from 'dotenv'

dotenvConfig()

import 'hardhat-gas-reporter'
import '@typechain/hardhat'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-deploy'
import 'solidity-coverage'

import { NetworksUserConfig, HardhatUserConfig } from 'hardhat/types'

const INFURA_API_KEY = process.env.INFURA_API_KEY
const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
const REPORT_GAS = Boolean(process.env.REPORT_GAS)

const networks: NetworksUserConfig = {
  hardhat: {},
  localhost: {},
  coverage: {
    url: 'http://127.0.0.1:8555', // Coverage launches its own ganache-cli client
  },
}

if (INFURA_API_KEY && RINKEBY_PRIVATE_KEY) {
  networks.rinkeby = {
    url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
    accounts: [RINKEBY_PRIVATE_KEY],
  }
}

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  gasReporter: {
    currency: 'EUR',
    enabled: REPORT_GAS,
    showTimeSpent: true,
  },
  networks
}

if (ETHERSCAN_API_KEY) {
  config.etherscan = {
    apiKey: ETHERSCAN_API_KEY,
  }
}

export default config

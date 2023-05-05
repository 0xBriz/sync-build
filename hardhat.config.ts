import * as dotenv from 'dotenv';
import { HardhatUserConfig } from 'hardhat/config';
// import "@nomicfoundation/hardhat-toolbox";
import '@matterlabs/hardhat-zksync-deploy';
import '@matterlabs/hardhat-zksync-solc';

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.7.1',
        // settings: {
        //   optimizer: {
        //     enabled: true,
        //     runs: 200,
        //   },
        // },
      },
    ],
  },
  zksolc: {
    version: '1.3.8',
    compilerSource: 'binary',
    settings: {
      // //compilerPath: "zksolc",  // optional. Ignored for compilerSource "docker". Can be used if compiler is located in a specific folder
      // experimental: {
      //   dockerImage: "matterlabs/zksolc", // Deprecated! use, compilerSource: "binary"
      //   tag: "latest"   // Deprecated: used for compilerSource: "docker"
      // },
      // libraries:{}, // optional. References to non-inlinable libraries
      // isSystem: false, // optional.  Enables Yul instructions available only for zkSync system contracts and libraries
      // forceEvmla: true, // optional. Falls back to EVM legacy assembly if there is a bug with Yul
      optimizer: {
        enabled: false, // optional. True by default
        // mode: '3' // optional. 3 by default, z to optimize bytecode size
      },
    },
  },
  networks: {
    hardhat: {
      zksync: true,
    },
    zkSyncTestnet: {
      url: 'https://testnet.era.zksync.dev', // The testnet RPC URL of zkSync Era network.
      ethNetwork: 'goerli', // The identifier of the network (e.g. `mainnet` or `goerli`)
      zksync: true, // Set to true to target zkSync Era.
    },
    zkSync: {
      url: '',
      ethNetwork: 'mainnet',
      zksync: true,
    },
    zkSyncLocal: {
      url: 'http://localhost:3050/',
      chainId: 270,
      zksync: true,
    },
  },
};

export default config;

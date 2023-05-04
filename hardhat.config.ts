import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.7.1",
        // settings: {
        //   optimizer: {
        //     enabled: true,
        //     runs: 200,
        //   },
        // },
      },
    ],
  },
  // zksolc: {
  //   version: "1.3.9",
  //   compilerSource: "binary",
  //   settings: {},
  // },
  networks: {
    hardhat: {
      // zksync: true,
    },
    zkSyncTestnet: {
      url: "https://testnet.era.zksync.dev", // The testnet RPC URL of zkSync Era network.
      ethNetwork: "goerli", // The identifier of the network (e.g. `mainnet` or `goerli`)
      zksync: true, // Set to true to target zkSync Era.
    },
    zkSync: {
      url: "",
      ethNetwork: "mainnet",
      zksync: true,
    },
    zkSyncLocal: {
      url: "http://localhost:3050/",
      chainId: 270,
      zksync: true,
    },
  },
};

export default config;

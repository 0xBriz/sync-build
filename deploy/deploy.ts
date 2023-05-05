import { utils, Wallet } from 'zksync-web3';
import * as ethers from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

export default async function main(hre: HardhatRuntimeEnvironment) {
  try {
    console.log(`Running deploy script for the Greeter contract`);

    // Initialize the wallet.
    const wallet = new Wallet(process.env.DEV_KEY);

    // Create deployer object and load the artifact of the contract we want to deploy.
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact('Greeter');

    // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
    // `greeting` is an argument for contract constructor.

    const contract = await deployer.deploy(artifact, []);

    // Show the contract info.
    const contractAddress = contract.address;
    console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });

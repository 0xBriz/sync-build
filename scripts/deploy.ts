import { ethers } from 'hardhat';

async function main() {
  const mathLib = await ethers.getContractFactory('WeightedMath');
  const libInstance = await mathLib.deploy();
  await libInstance.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

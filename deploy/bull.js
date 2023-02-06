const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");
const dotenv = require('dotenv');
const TOPIAJSON = require('../artifacts/contracts/TOPIA.sol/TOPIA.json')
const BullJSON = require('../artifacts/contracts/Bull.sol/Bull.json')
const BullTraitJSON = require('../artifacts/contracts/BullTraits.sol/BullTraits.json')
const PoolJSON = require('../artifacts/contracts/Pool.sol/Pool.json')
const hre = require("hardhat");

dotenv.config();

const {sleep, _getContract} = require('../scripts/utils');


const TOPIA_ADDR = process.env.TOPIA_ADDR;
const BULLTRAIT_ADDR = process.env.BULLTRAIT_ADDR;
const POOL_ADDR = process.env.POOL_ADDR;
const MaxTokens = parseInt(process.env.MaxTokens);


async function updateBullOfTraitContract(_bullAddr, _bullTraitAddr){
  if (!_bullTraitAddr) {
    console.log('Skipped updating bull address at BullTrait contract as BULLTRAIT_ADDR is empty at env.')
  }
  console.log('Updating bull of trait...')
  const bullTraits = _getContract(_bullTraitAddr, BullTraitJSON.abi, false)
  await bullTraits.setBull(_bullAddr);
  console.log('Updated bull of trait!')
}

async function updateBullOfPoolContract(_bullAddr){
  if (!POOL_ADDR) {
    console.log('Skipped updating bull address at Pool contract as POOL_ADDR is empty at env.')
    return;
  }
  console.log('Updating bull of Pool...')
  const pool = _getContract(POOL_ADDR, PoolJSON.abi, false)
  await pool.setBull(_bullAddr);
  console.log('Updated bull of Pool!')
}

async function updatePoolOfBull(_poolAddr, bullCont) {
  
  console.log('Updating Pool of Bull...')
  await bullCont.setPool(_poolAddr);
  console.log('Updated Pool of Bull!')
}


async function verifyBull(_bullAddr) {

  if (!TOPIA_ADDR) {
    console.log('Skipped veirfing bull contract because TOPIA_ADDR is empty at env.')
    return;
  }
  if (!BULLTRAIT_ADDR) {
    console.log('Skipped veirfing bull contract because BULLTRAIT_ADDR is empty at env.')
    return;
  }
  if (!process.env.RINKEBY_VRF_Coordinator_V2) {
    console.log('Skipped veirfing bull contract because RINKEBY_VRF_Coordinator_V2 is empty at env.')
    return;
  }
  if (!process.env.SUBSCRIPTION_ID) {
    console.log('Skipped veirfing bull contract because SUBSCRIPTION_ID is empty at env.')
    return;
  }

  if  (!(MaxTokens > 0)) {
    console.log('Skipped veirfing bull contract because MaxTokens is not correct number at env.')
    return;
  }



  console.log("Begin verify Bull");
  await sleep(10000)
  try{
    await hre.run("verify:verify", {
      address: _bullAddr,
      constructorArguments: [
        TOPIA_ADDR,
        BULLTRAIT_ADDR,
        MaxTokens, // 50000
        process.env.RINKEBY_VRF_Coordinator_V2,
        process.env.SUBSCRIPTION_ID
      ],
    });
    console.log("Done verify Bull");
    return true;
  }catch(ex){
    console.log(ex)
    console.log('Sleeping and try verify again in 10s')
    await sleep(10000)
    return await verifyBull(_bullAddr)
  }
    
}

async function deployBull(){
    console.log('deploying Bull .... ')
    if (!TOPIA_ADDR) {
      console.log('Skipped veirfing bull contract because TOPIA_ADDR is empty at env.')
      return;
    }
    if (!BULLTRAIT_ADDR) {
      console.log('Skipped veirfing bull contract because BULLTRAIT_ADDR is empty at env.')
      return;
    }
    if (!process.env.RINKEBY_VRF_Coordinator_V2) {
      console.log('Skipped veirfing bull contract because RINKEBY_VRF_Coordinator_V2 is empty at env.')
      return;
    }
    if (!process.env.SUBSCRIPTION_ID) {
      console.log('Skipped veirfing bull contract because SUBSCRIPTION_ID is empty at env.')
      return;
    }

    const BullFactory = await ethers.getContractFactory("Bull");
    const MaxTokens = 20000;
    
    const bull = await BullFactory.deploy(
      TOPIA_ADDR,
      BULLTRAIT_ADDR,
      MaxTokens, // 50000
      process.env.RINKEBY_VRF_Coordinator_V2,
      process.env.SUBSCRIPTION_ID
    );
    await bull.deployed();
    
    console.log("Bull deployed", bull.address);
    // verify bull contract
    await verifyBull(bull.address)

    // update bull address of trait

    await updateBullOfTraitContract(bull.address,BULLTRAIT_ADDR )

    // update bull address of pool

    await updateBullOfPoolContract(bull.address);

    // update pool address of Bull

    if (!POOL_ADDR) {
      console.log('Skipped updating pool address at Bull contract because POOL_ADDR is empty at env.')
      return;
    }

    await updatePoolOfBull(POOL_ADDR, bull);

}



async function main(){
  await deployBull();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

module.exports = {
  sleep,
  _getContract,
  updatePoolOfBull,
  deployBull
}
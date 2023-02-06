const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");
const dotenv = require('dotenv');
const BullJSON = require('../artifacts/contracts/Bull.sol/Bull.json')

const hre = require("hardhat");
const {sleep, _getContract} = require('../scripts/utils');

dotenv.config();


const TOPIA_ADDR = process.env.TOPIA_ADDR;
const BULL_ADDR = process.env.BULL_ADDR;
const RANDOMNESS_ADDR = process.env.RANDOMNESS_ADDR;


async function verifyPool(_poolAddr, bullAddr, topiaAddr, randomnessAddr) {
  console.log("Begin verify POOL");

  if (!bullAddr) {
    console.log('Skipped veirfing Pool contract because bullAddr is empty at env.')
    return;
  }
  if (!topiaAddr) {
    console.log('Skipped veirfing Pool contract because topiaAddr is empty at env.')
    return;
  }
  if (!randomnessAddr) {
    console.log('Skipped veirfing Pool contract because randomnessAddr is empty at env.')
    return;
  }

  // if (!process.env.RINKEBY_VRF_Coordinator_V2) {
  //   console.log('Skipped veirfing Pool contract because RINKEBY_VRF_Coordinator_V2 is empty at env.')
  //   return;
  // }
  // if (!process.env.SUBSCRIPTION_ID) {
  //   console.log('Skipped veirfing Pool contract because SUBSCRIPTION_ID is empty at env.')
  //   return;
  // }
  // if (!process.env.RINKEBY_LINK_Token) {
  //   console.log('Skipped veirfing Pool contract because RINKEBY_LINK_Token is empty at env.')
  //   return;
  // }


  await hre.run("verify:verify", {
    address: _poolAddr,
    constructorArguments: [
      bullAddr,
      topiaAddr,
      randomnessAddr
    ],
  });
  console.log("Done verify POOL");
}


async function deployPool(_bullAddr, _topiaAddr, _randomnessAddr){
    const PoolFactory = await ethers.getContractFactory("Pool");
    const pool = await PoolFactory.deploy(
      _bullAddr,
      _topiaAddr,
      _randomnessAddr
    );
    await pool.deployed();
    console.log("Pool deployed", pool.address);
    return pool.address;
}

async function asyncVerifyPool(_poolAddr, bullAddr, topiaAddr, randomnessAddr) {
  await sleep(10000)
  try{
    await verifyPool(_poolAddr, bullAddr,topiaAddr, randomnessAddr )
    return true;
  }catch(ex){
    return await asyncVerifyPool(_poolAddr, bullAddr, topiaAddr, randomnessAddr);
  }
}

async function updatePoolOfBull(_poolAddr, bullCont) {
  console.log('Updating Pool of Bull...')
  await bullCont.setPool(_poolAddr);
  console.log('Updated Pool of Bull!')
}



async function main(){
  
  if (!BULL_ADDR) {
    console.log('Skipped deploying Pool contract because BULL_ADDR is empty at env.')
    return;
  }
  if (!TOPIA_ADDR) {
    console.log('Skipped deploying Pool contract because TOPIA_ADDR is empty at env.')
    return;
  }
    const newPoolAddr = await deployPool(BULL_ADDR, TOPIA_ADDR);
    await asyncVerifyPool(newPoolAddr, BULL_ADDR, TOPIA_ADDR, RANDOMNESS_ADDR);

    const bull = _getContract(BULL_ADDR, BullJSON.abi, false);
    await updatePoolOfBull(newPoolAddr, bull);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });



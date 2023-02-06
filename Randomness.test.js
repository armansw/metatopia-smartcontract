const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");

/**
 * We assume loan currency is native coin
 */


// console.log(JSON.parse(json))
function sleep(ms){
  return new Promise(resolve=>setTimeout(resolve, ms))
}

describe("Randomness.test", function () {
    
  before(async function () {
    this.randomnessFactory = await ethers.getContractFactory("Randomness");
    
    this.signers = await ethers.getSigners();

    console.log(
      `on hardhat signers:`,
      this.signers.length
    );

  });

  beforeEach(async function () {
    
      this.randomness = await this.randomnessFactory.deploy();
      await this.randomness.deployed();
      console.log('Randomness deployed: ', this.randomness.address);
      
  });

  it('getRandom..', async function(){
    await this.randomness.updateCaller(this.signers[0].address)
    // const addresses = this.signers.map(one=>one.address);
    // const _param = addresses.join(',')
    // console.log('addresses', addresses, addresses.length);
    let rands = [];
    let countZero = 0;
    for (let i=0; i<100; i++){
      // await sleep(1000)
      const res = await this.randomness.getRandom(i);
      rands.push(res.toString())
      console.log('Randomeness result: ', res.toString(), ' mod:',  res.mod(4).toString())

      countZero += res.mod(2).eq(0) ? 1 : 0;
      

    }
    
    console.log('Zero count:', countZero, ' 1 count:', 100 - countZero)

  })



});




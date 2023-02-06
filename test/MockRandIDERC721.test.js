const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");

/**
 * We assume loan currency is native coin
 */

// console.log(JSON.parse(json))

describe("MockRandIDERC721.test", function () {
  before(async function () {
    this.mockNFTFactory = await ethers.getContractFactory("MockRandIDERC721");

    this.signers = await ethers.getSigners();

    console.log(`on hardhat signers:`, this.signers.length);
  });

  beforeEach(async function () {
    this.mockNFT = await this.mockNFTFactory.deploy();
    await this.mockNFT.deployed();
    console.log("Mock NFT deployed: ", this.mockNFT.address);
  });

  it('Mint..', async function(){

    const addresses = this.signers.map(one=>one.address);
    // const _param = addresses.join(',')
    console.log('addresses', addresses, addresses.length);

    const _addresses = addresses.slice(0,10);
    console.log('_addresses: ', _addresses);
    await this.mockNFT.mint(
      _addresses
    );

    for (let i=1; i<=10;i++){

      console.log(`${i} : ${i}`);
      try{
        const owner = await this.mockNFT.ownerOf(i);
        console.log(`Owner of token:${i}: ${owner}`)
      }catch(ex){
        console.error(ex.message)

      }

    }

  })

  it("test selids ...", async function () {
    console.log("this.mockNFT.address: ", this.mockNFT.address);
    let selIds = [1, 4, 2, 234, 345, 34, 34, 34, 23];
    // for(let i=0; i<10; i++){
    //   selIds = [...selIds, ...selIds.map(one=>one*(i+1))];
    // }
    

    const loopCount = 20000;
    for (let i = 0; i < loopCount; i++) {
      await this.mockNFT.addSelIds(selIds);
    }

    const originLen = selIds.length  * loopCount;

    console.log("Origin length : ", originLen);

    for (let i = 0; i < selIds.length; i++) {
      const _id = await this.mockNFT.getItemAtSelIds(i);
      console.log(`index : ${i}, selid: ${_id}`);
    }

    console.log("Remove items >>>");

    

    await this.mockNFT.removeItemAtSelIds(0);

    for (let i = 0; i < selIds.length; i++) {
      const _id = await this.mockNFT.getItemAtSelIds(i);
      console.log(`index : ${i}, selid: ${_id}`);
    }

    const newLen = await this.mockNFT.getLengthIds();

    console.log("newLen:", newLen);
    expect(newLen).eq(originLen - 1, "Remove is not working correctly");

    await this.mockNFT.removeItemAtSelIds(0);
    const _newLen2 = await this.mockNFT.getLengthIds();
    expect(_newLen2).eq(originLen - 2, "Remove is not working correctly");

    await this.mockNFT.removeItemAtSelIds(2);
    const _newLen3 = await this.mockNFT.getLengthIds();
    expect(_newLen3).eq(originLen - 3, "Remove is not working correctly");
  });
});

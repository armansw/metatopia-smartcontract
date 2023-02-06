
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");
const dotenv = require('dotenv');


dotenv.config();


async function deployBullTraits(){

    console.log('deploying BullTraits .... ')
    const BullTraits = await ethers.getContractFactory("BullTraits");
    const defaultImage = 'https://ipfs.io/ipfs/QmQ1SN1FU373dQSwXdLCEum6x1uSChhjmndcwRrJuHhWUx';
    this.bullTraits = await BullTraits.deploy(defaultImage);
    await this.bullTraits.deployed();
    console.log("BullTraits deployed", this.bullTraits.address);

}

async function main(){
    await deployBullTraits();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

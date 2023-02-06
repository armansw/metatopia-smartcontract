const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");
const dotenv = require('dotenv');


dotenv.config();


async function deployTOPIA(){
    console.log('deploying TOPIA .... ')
    const TopiaToken = await ethers.getContractFactory("TOPIA");
    this.topia = await TopiaToken.deploy();
    await this.topia.deployed();
    console.log("TOPIA deployed", this.topia.address);
    return this.topia.address;
}


async function main(){
    await deployTOPIA();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

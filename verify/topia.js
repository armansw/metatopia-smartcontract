const hre = require("hardhat");
const dotenv = require("dotenv");

dotenv.config();

const TOPIA_ADDR = process.env.TOPIA_ADDR;
const BULLTRAIT_ADDR = process.env.BULLTRAIT_ADDR;
const BULL_ADDR = process.env.BULL_ADDR;
const POOL_ADDR = process.env.POOL_ADDR;

const MaxTokens = parseInt(process.env.MaxTokens);

async function verifyTOPIA() {
  console.log("Begin verify TOPIA");
  await hre.run("verify:verify", {
    address: TOPIA_ADDR,
    constructorArguments: [],
  });
  console.log("Done verify TOPIA");
}

async function main() {
  
  await verifyTOPIA();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

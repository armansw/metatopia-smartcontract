const hre = require("hardhat");
const dotenv = require("dotenv");

dotenv.config();

const TOPIA_ADDR = process.env.TOPIA_ADDR;
const BULLTRAIT_ADDR = process.env.BULLTRAIT_ADDR;
const BULL_ADDR = process.env.BULL_ADDR;
const POOL_ADDR = process.env.POOL_ADDR;

const MaxTokens = parseInt(process.env.MaxTokens);

async function verifyPool(_poolAddr) {
  console.log("Begin verify POOL");

  await hre.run("verify:verify", {
    address: _poolAddr,
    constructorArguments: [
        BULL_ADDR,
        TOPIA_ADDR,
        process.env.RINKEBY_VRF_Coordinator_V2, // VRF Coordinator
        process.env.SUBSCRIPTION_ID, // LINK Token
        process.env.RINKEBY_LINK_Token
    ],
  });
  console.log("Done verify POOL");
}

async function main() {
  
  await verifyPool(POOL_ADDR);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


module.exports = {
  verifyPool
}
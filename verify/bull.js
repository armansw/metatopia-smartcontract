const hre = require("hardhat");
const dotenv = require("dotenv");

dotenv.config();

const TOPIA_ADDR = process.env.TOPIA_ADDR;
const BULLTRAIT_ADDR = process.env.BULLTRAIT_ADDR;
const BULL_ADDR = process.env.BULL_ADDR;
const POOL_ADDR = process.env.POOL_ADDR;

const MaxTokens = parseInt(process.env.MaxTokens);


async function verifyBull() {
  console.log("Begin verify Bull");

  await hre.run("verify:verify", {
    address: BULL_ADDR,
    constructorArguments: [
      TOPIA_ADDR,
      BULLTRAIT_ADDR,
      MaxTokens, // 50000
      process.env.RINKEBY_VRF_Coordinator_V2,
      process.env.SUBSCRIPTION_ID
    ],
  });
  console.log("Done verify Bull");
}

async function main() {
  await verifyBull();
  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

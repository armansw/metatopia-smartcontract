const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const BN = require("bignumber.js");

const TOPIAJSON = require("./artifacts/contracts/TOPIA.sol/TOPIA.json");
const BullJSON = require("./artifacts/contracts/Bull.sol/Bull.json");
const BullTraitJSON = require("./artifacts/contracts/BullTraits.sol/BullTraits.json");
const PoolJSON = require("./artifacts/contracts/Pool.sol/Pool.json");

/**
 * We assume loan currency is native coin
 */

const TEST_NETWORK = "hardhat";

const TOPIA_ADDR = "0xD960673086Af8d5008d164eF686bC6AB11b0dE9A";
const BULLTRAIT_ADDR = "0x5AA820E249063900F6E434e037526F2b9C8d470e";
const BULL_ADDR = "0xD09C5FdbAa66163446ecFC6453608af940cd5fd4";
const POOL_ADDR = "0xB022e00182e78F6de9CEDE4aD42e115Ee96f8a4B";

// console.log(JSON.parse(json))

function _getProviderUrls() {
  const NODE_API_KEY = process.env.INFURA_KEY;
  const network = "rinkeby";

  let infuraRpcSubproviderRPCUrl =
    "https://" + network + ".infura.io/v3/" + NODE_API_KEY;

  let res = process.env.PUBLIC_ETH_RPC_JSON_RINKEBY;
  res = infuraRpcSubproviderRPCUrl;
  // if (serverNodeProvider == NodeProvider.Infura) res = infuraRpcSubproviderRPCUrl
  // else if (serverNodeProvider == NodeProvider.Default) res = ETH_RPC_URL

  return res;
}

function _getContract(contractAddr, abi, privKey, withoutSigner = true) {
  const RPC_URL = _getProviderUrls();
  const ethProvider = new ethers.providers.JsonRpcProvider(RPC_URL);

  let contract;
  if (withoutSigner) {
    contract = new ethers.Contract(contractAddr, abi, ethProvider);
  } else {
    const wallet = new ethers.Wallet(privKey, ethProvider);
    contract = new ethers.Contract(contractAddr, abi, wallet);
  }
  return contract;
}

describe("Bull", function () {
  const MOCK_SUBSCRIPTION_ID = 0;
  const MOCK_LINK = ethers.constants.AddressZero;

  const MAX_TOKENS = parseInt(process.env.MaxTokens);

  

  async function deployContractMockVRF() {
    const vrfCoordinatorContract = "MockVRFCoordinator";

    const vrfCoordFactory = await ethers.getContractFactory(
      vrfCoordinatorContract
    );
    const mockVrfCoordinator = await vrfCoordFactory.deploy();

    return {
      mockVrfAddress: mockVrfCoordinator.address,
      mockLinkToken: MOCK_LINK,
      mockSubScriptionId: MOCK_SUBSCRIPTION_ID,
    };
  }

  before(async function () {
    this.Bull = await ethers.getContractFactory("Bull");
    this.TOPIA = await ethers.getContractFactory("TOPIA");
    this.BullTraits = await ethers.getContractFactory("BullTraits");
    this.Pool = await ethers.getContractFactory("Pool");

    this.signers = await ethers.getSigners();

    console.log(
      `on ${TEST_NETWORK} signers:`,
      this.signers[0].address,
      this.signers.length
    );

    if (TEST_NETWORK != "hardhat") {
      this.topia = _getContract(TOPIA_ADDR, TOPIAJSON.abi);
      this.bull = _getContract(BULL_ADDR, BullJSON.abi);
      this.bullTraits = _getContract(BULLTRAIT_ADDR, BullTraitJSON.abi);
      this.pool = _getContract(POOL_ADDR, PoolJSON.abi);

      console.log("this.topia:", this.topia.address);
      console.log("this.bull:", this.bull.address);
      console.log("this.bullTraits:", this.bullTraits.address);
      console.log("this.pool:", this.pool.address);
    }
  });

  beforeEach(async function () {
    if (TEST_NETWORK == "hardhat") {
      this.topia = await this.TOPIA.deploy();
      await this.topia.deployed();
      await this.topia.addController(this.signers[0].address);
      await this.topia.mint(
        this.signers[0].address,
        ethers.utils.parseEther("10000")
      );

      // console.log("TopiaToken deployed", this.topia.address);

      const defaultImage =
        "https://ipfs.io/ipfs/QmQ1SN1FU373dQSwXdLCEum6x1uSChhjmndcwRrJuHhWUx";
      this.bullTraits = await this.BullTraits.deploy(defaultImage);
      await this.bullTraits.deployed();
      // console.log("BullTraits deployed", this.bullTraits.address);

      const { mockVrfAddress, mockLinkToken, mockSubScriptionId } = await deployContractMockVRF();
      
      // console.log({ mockVrfAddress, mockLinkToken, mockSubScriptionId });

      this.bull = await this.Bull.deploy(
        this.topia.address,
        this.bullTraits.address,
        process.env.MaxTokens, // 50000
        mockVrfAddress,
        mockSubScriptionId
      );
      await this.bull.deployed();
      await this.topia.addController(this.bull.address);
      console.log("added bull as controller : ", this.bull.address);
      // console.log("Bull deployed", this.bull.address);

      await this.bullTraits.setBull(this.bull.address);

      this.pool = await this.Pool.deploy(
        this.bull.address,
        this.topia.address,
        mockVrfAddress, // VRF Coordinator
        mockSubScriptionId, // LINK Token
        mockLinkToken
      );

      await this.pool.deployed();
      await this.bull.setPool(this.pool.address);

      // console.log("Pool deployed", this.pool.address);
    }
  });

  /**
   * Mint Cost test
   */

  it("Trying mintCost function in Bull.sol", async function () {
    const owner = await this.bull.owner();
    console.log(`owner of bull (${this.bull.address}):  ${owner}`);
    const mintInTopia = await this.bull.MINT_IN_TOPIA();
    expect(mintInTopia).eq(false);

    const mintPrice = await this.bull.MINT_PRICE();
    expect(mintPrice).eq(ethers.utils.parseEther("0.05"));

    const mintCost10 = await this.bull.mintCost(10);

    const expectPrice = 0.05 * 9;
    expect(mintCost10).eq(ethers.utils.parseEther(expectPrice + ""));

    const mintCost21 = await this.bull.mintCost(22);

    const expectPrice21 = 0.05 * 20;
    console.log({ expectPrice21 });
    expect(mintCost21).eq(ethers.utils.parseEther(expectPrice21 + ""));
  });

  it("Whitelisted checking..", async function () {
    const owner = await this.bull.owner();
    console.log("Owner of bull:", owner);
    const isWhitelisted = await this.bull.getWhitelisted(owner);

    expect(isWhitelisted).eq(
      true,
      "Owner of bull contract must be whitelisted normally."
    );
    expect(await this.bull.getWhitelisted(this.signers[1].address)).eq(
      false,
      "At first, Only owner is whitelisted."
    );
    expect(await this.bull.getWhitelisted(this.signers[2].address)).eq(
      false,
      "At first, Only owner is whitelisted."
    );

    let noneOwnerCanAddWhitelist = undefined;
    try {
      await this.bull.connect(this.signers[1]).addWhitelisted(this.signers[2]);
      noneOwnerCanAddWhitelist = true;
    } catch (ex) {
      // console.log('exception while checking addwhitelist of noneOwner', ex)
      noneOwnerCanAddWhitelist = false;
    }

    expect(noneOwnerCanAddWhitelist).to.equal(false);

    let ownerCanAddWhiteList = undefined;

    try {
      const iswhitelisted = await this.bull.getWhitelisted(
        this.signers[1].address
      );
      console.log(
        `${this.signers[1].address} is whitelisted ? ${iswhitelisted}`
      );
      console.log(
        `AddWhitelisted ${this.signers[1].address} by ${this.signers[0].address}`
      );
      await this.bull
        .connect(this.signers[0])
        .addWhitelisted(this.signers[1].address);

      ownerCanAddWhiteList = true;
      console.log("Now signer 1 is whitelisted.");
      expect(await this.bull.getWhitelisted(this.signers[1].address)).eq(true);
    } catch (ex) {
      console.log("Exception at addWhitelist by owner", ex);
      ownerCanAddWhiteList = false;
    }

    expect(ownerCanAddWhiteList).to.equal(true);

    let ownerCanRemoveWhiteList = undefined;

    try {
      const iswhitelisted = await this.bull.getWhitelisted(
        this.signers[1].address
      );
      console.log(
        `${this.signers[1].address} is whitelisted ? ${iswhitelisted}`
      );
      console.log(
        `RemoveWhitelisted ${this.signers[1].address} by ${this.signers[0].address}`
      );
      await this.bull
        .connect(this.signers[0])
        .removeWhitelisted(this.signers[1].address);

      ownerCanRemoveWhiteList = true;
      console.log("Now signer 1 is removed from whitelist.");
      expect(await this.bull.getWhitelisted(this.signers[1].address)).eq(false);
    } catch (ex) {
      console.log("Exception at addWhitelist by owner", ex);
      ownerCanRemoveWhiteList = false;
    }

    expect(ownerCanRemoveWhiteList).to.equal(true);
  });

  it("Test SetMINMINT..", async function () {
    await this.bull
      .connect(this.signers[0])
      .addWhitelisted(this.signers[1].address);
    let whitelistedMemberCanSetMINMINT = undefined;
    try {
      await this.bull.connect(this.signers[1]).setMIN_MINT(2);

      whitelistedMemberCanSetMINMINT = true;
    } catch (ex) {
      whitelistedMemberCanSetMINMINT = false;
    }

    expect(whitelistedMemberCanSetMINMINT).eq(true);

    let noMemberCanNotSet;

    try {
      await this.bull.connect(this.signers[2]).setMIN_MINT(2);

      noMemberCanNotSet = true;
    } catch (ex) {
      noMemberCanNotSet = false;
    }
    expect(noMemberCanNotSet).eq(false);
  });

  it("Set MINT Price by owner.", async function () {
    const newMINTPrice = ethers.utils.parseEther("0.02");
    await this.bull.setMintPrice(newMINTPrice, true);

    const mintPrice = await this.bull.MINT_PRICE();

    expect(mintPrice).eq(newMINTPrice);

    const mintInTopia = await this.bull.MINT_IN_TOPIA();
    expect(mintInTopia).eq(true);
  });

  /**
   * Mint Test for amount 1, no staking
   *
   */

  it("Trying Mint NFT amount 5, stake in Bull.sol", async function () {
    
    const originBalanceofTopia = await this.topia.balanceOf(
      this.signers[0].address
    );
    console.log(
      "Owner TOPIA balance: ",
      ethers.utils.formatEther(originBalanceofTopia)
    );

    await this.bull.setMintPrice(ethers.utils.parseEther("0.02"), true);
    console.log(
      "Mint Price: ",
      ethers.utils.formatEther(await this.bull.MINT_PRICE())
    );
    console.log("Mint in TOPIA:", await this.bull.MINT_IN_TOPIA());

    // const repeatCount = 1;

    // for (let i = 0; i < repeatCount; i++) {
    // const totalMinted = await this.bull.minted();
    // console.log("TotalMinted:", totalMinted);
    // const next = totalMinted + 1;

    const amount = 10;
    const stake = false;

    const mintCost = await this.bull.mintCost(amount);
    console.log('MintCost :', ethers.utils.formatEther(mintCost));
    await this.bull.mint(amount, stake);

    const expectedBal = originBalanceofTopia.sub(mintCost);
    // }

    /**
     * check balance of bull contract
     */
    const curBalanceOfTopia = await this.topia.balanceOf(
      this.signers[0].address
    );
    console.log("After mint TOPIA Balance of Owner : ", ethers.utils.formatEther(curBalanceOfTopia) );

    expect(curBalanceOfTopia).eq(expectedBal);

    console.log(
      "Bull contract balance:",
      ethers.utils.formatEther(
        await ethers.provider.getBalance(this.bull.address)
      )
    );
  });

  // it('Trying setPaused function in Matador.sol', async function () {

  //   const owner = await this.matador.owner();
  //   console.log(`owner ${this.matador.address} ${owner}`);

  //   await expect(await this.matador.setPaused(true))
  //     .to.emit(this.matador, 'Paused')
  //     .withArgs(owner);

  //   await expect(await this.matador.setPaused(false))
  //     .to.emit(this.matador, 'Unpaused')
  //     .withArgs(owner);

  // });

  // it('Trying isRunner function call with Matador.sol', async function () {

  //   const owner = await this.matador.owner();
  //   console.log(`owner ${this.matador.address} ${owner}`);

  //   const tokenIds = [1];

  //   for (let tokenId of tokenIds) {
  //     expect(await this.matador.isRunner(tokenId)).to.be.equal(false);
  //   }

  // });

  // it('Trying totalRunnerStaked function call with Matador.sol', async function () {

  //   const owner = await this.matador.owner();
  //   console.log(`owner ${this.matador.address} ${owner}`);
  //   console.log('totalRunnerStaked::', await this.matador.totalRunnerStaked());
  //   await expect(await this.matador.totalRunnerStaked()).to.be.equal(0);

  // });

  // it('Trying addManyToMatadorAndPack function call with Matador.sol', async function () {

  // nst owner = await this.matador.owner();
  // console.log(`owner ${this.matador.address} ${owner}`);

  //   const tokenIds = [1];

  //   await expect(this.matador.addManyToMatadorAndPack(owner, tokenIds))
  // .to.emit(this.matador, 'TokenStaked')
  //     .withArgs(owner, tokenIds[0], block.timestamp);

  // });

  // it('Trying claimManyFromMatadorAndPack function call with Matador.sol', async function () {

  //  const owner = await this.matador.owner();
  //   console.log(`owner ${this.matador.address} ${owner}`);

  //  const tokenIds = [1];

  //  await expect(this.matador.claimManyFromMatadorAndPack(tokenIds, false))
  //     .to.emit(this.matador, 'WolfClaimed')
  //     .withArgs(tokenIds[0], owed, false);

  // });

  // it('Trying rescue function call with Matador.sol', async function () {

  //  const owner = await this.matador.owner();
  //   console.log(`owner ${this.matador.address} ${owner}`);

  //  const tokenIds = [1];

  //   await expect(this.matador.rescue(tokenIds))
  //     .to.emit(this.matador, 'WolfClaimed')
  //  .withArgs(tokenIds[0], 0, true);

  // });
});

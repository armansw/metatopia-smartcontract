const dotenv = require('dotenv');
const { ethers, network } = require("hardhat");
dotenv.config();
function sleep(ms){
    return new Promise((resolve, reject)=>{
      setTimeout(() => {
        resolve();
      }, ms);
    })
  }

  

const SIGNER_KEY=process.env.PRIV_KEY_SIGNER;

function _getProviderUrls() {
  const NODE_API_KEY = process.env.INFURA_KEY
  const network = 'rinkeby'

  let infuraRpcSubproviderRPCUrl = 'https://' + network + '.infura.io/v3/' + NODE_API_KEY

  let res = process.env.PUBLIC_ETH_RPC_JSON_RINKEBY
  res = infuraRpcSubproviderRPCUrl
  // if (serverNodeProvider == NodeProvider.Infura) res = infuraRpcSubproviderRPCUrl
  // else if (serverNodeProvider == NodeProvider.Default) res = ETH_RPC_URL

  return res
}

function _getContract (contractAddr, abi, withoutSigner = true) {
  const RPC_URL =  _getProviderUrls()
  const ethProvider = new ethers.providers.JsonRpcProvider(RPC_URL)

  let contract
  if (withoutSigner) {
    contract = new ethers.Contract(contractAddr, abi, ethProvider)
  } else {
    const wallet = new ethers.Wallet(SIGNER_KEY, ethProvider)
    contract = new ethers.Contract(contractAddr, abi, wallet)
  }
  return contract
}


module.exports = {
    sleep,
    _getProviderUrls,
    _getContract,
}
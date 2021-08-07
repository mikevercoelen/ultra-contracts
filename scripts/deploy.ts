import 'dotenv/config'

import { ethers } from 'hardhat'
import {
  UltrareumERC721,
  ERC721AuctionHouse,
  UltrareumERC721__factory,
  ERC721AuctionHouse__factory
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const BASE_TOKEN_URI = process.env.BASE_TOKEN_URI || 'https://ultrareum.nft.com/'
const WETH_ADDRESS = process.env.WETH_ADDRES || '0xc778417e063141139fce010982780140aa0cd5ab' // Rinkeby WETH address
const SERVICE_CUT = Number(process.env.SERVICE_CUT || 1000)
const INITIAL_CUT = Number(process.env.INITIAL_CUT || 1000)
const NATIVE_USED = Boolean(process.env.NATIVE_USED || true) // Set this to false if we deploy to Polygon etc.

interface UltraDeployProps {
  deployer: SignerWithAddress;
  baseTokenUri: string;
  serviceCut: number;
  initialCut: number;
  wethAddress: string;
  nativeUsed: boolean;
}

export const deployUltraContracts = async (deployProps: UltraDeployProps): Promise<[UltrareumERC721, ERC721AuctionHouse]> => {
  // ERC721
  const ultrareumERC721Factory = (await ethers.getContractFactory('UltrareumERC721', deployProps.deployer)) as UltrareumERC721__factory;
  const ultrareumERC721 = await ultrareumERC721Factory.deploy(deployProps.baseTokenUri);
  await ultrareumERC721.deployed();

  // AuctionHouse
  const erc721AuctionHouseFactory = (await ethers.getContractFactory('ERC721AuctionHouse')) as ERC721AuctionHouse__factory;
  const erc721AuctionHouse = await erc721AuctionHouseFactory.deploy(
    deployProps.serviceCut,
    deployProps.initialCut,
    deployProps.wethAddress,
    deployProps.nativeUsed
  );

  await erc721AuctionHouse.deployed();

  return [
    ultrareumERC721,
    erc721AuctionHouse
  ]
}

async function main() {
  const [deployer] = await ethers.getSigners()

  const deployProps = {
    deployer,
    baseTokenUri: BASE_TOKEN_URI,
    serviceCut: SERVICE_CUT,
    initialCut: INITIAL_CUT,
    wethAddress: WETH_ADDRESS,
    nativeUsed: NATIVE_USED
  }

  const [erc721, auctionHouse] = await deployUltraContracts(deployProps);

  // eslint-disable-next-line no-console
  console.log(
    `Ultra contract deployed at, ERC721: ${erc721.address} and AuctionHouse: ${auctionHouse.address}`
  )

  // eslint-disable-next-line no-console
  console.log(
    `To verify ERC721 contract on Etherscan: 'yarn run hardhat verify ${erc721.address} --constructor-args args-erc721.js --network rinkeby'`
  )

  // eslint-disable-next-line no-console
  console.log(
    `To verify AuctionHouse on Etherscan: 'yarn run hardhat verify ${auctionHouse.address} --constructor-args args-auction-house.js --network rinkeby'`
  )

  await erc721.deployed()
  await auctionHouse.deployed()
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    // eslint-disable-next-line no-console
    console.log(error)
    process.exit(1)
  })

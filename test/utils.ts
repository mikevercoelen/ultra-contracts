import { ethers } from 'hardhat'
import { BadBidder, WETH, BadERC721, TestERC721, UltrareumERC721 } from '../typechain'
import { BigNumber } from 'ethers'

export const THOUSANDTH_ETH = ethers.utils.parseUnits('0.001', 'ether') as BigNumber
export const TENTH_ETH = ethers.utils.parseUnits('0.1', 'ether') as BigNumber
export const ONE_ETH = ethers.utils.parseUnits('1', 'ether') as BigNumber
export const TWO_ETH = ethers.utils.parseUnits('2', 'ether') as BigNumber

export const deployWETH = async (): Promise<WETH> => {
  const [deployer] = await ethers.getSigners()
  return (await (await ethers.getContractFactory('WETH')).deploy()) as WETH
}

export const deployOtherNFTs = async (): Promise<{ bad: BadERC721; test: TestERC721 }> => {
  const bad = (await (await ethers.getContractFactory('BadERC721')).deploy()) as BadERC721
  const test = (await (await ethers.getContractFactory('TestERC721')).deploy()) as TestERC721

  return { bad, test }
}

export const deployMainNFT = async (): Promise<UltrareumERC721> => {
  return (await (await ethers.getContractFactory('UltrareumERC721')).deploy('')) as UltrareumERC721
}

export const deployBidder = async (auction: string): Promise<BadBidder> => {
  return (await (
    await (await ethers.getContractFactory('BadBidder')).deploy(auction)
  ).deployed()) as BadBidder
}

export const revert = (messages: TemplateStringsArray): string =>
  `VM Exception while processing transaction: revert ${messages[0]}`

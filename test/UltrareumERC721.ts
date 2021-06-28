/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { Contract } from '@ethersproject/contracts'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

chai.use(solidity)

describe('UltrareumERC721', function () {
  let tripcipERC721: Contract
  let deployerAddress: SignerWithAddress
  let minterAddress: SignerWithAddress

  before(async function () {
    ;[deployerAddress, minterAddress] = await ethers.getSigners()

    const UltrareumERC721 = await ethers.getContractFactory('UltrareumERC721')
    tripcipERC721 = await UltrareumERC721.connect(deployerAddress).deploy('https://test.url/')
    await tripcipERC721.deployed()
  })

  describe('#constructor', () => {
    it('should be able to deploy', async function () {
      expect(await tripcipERC721.name()).to.equal('UltrareumERC721')
      expect(await tripcipERC721.symbol()).to.equal('TC721')
    })
  })

  describe('#mint', () => {
    it('should emit CreateToken event', async function () {
      const block = await ethers.provider.getBlockNumber()
      await tripcipERC721.connect(minterAddress).mint(100, 'metadata')

      const events = await tripcipERC721.queryFilter(
        tripcipERC721.filters.CreateToken(null, null, null, null, null),
        block
      )
      expect(events.length).eq(1)
      const logDescription = tripcipERC721.interface.parseLog(events[0])
      expect(logDescription.name).to.eq('CreateToken')
      expect(logDescription.args.tokenId).to.eq(0)
      expect(logDescription.args.tokenMinter).to.eq(minterAddress.address)
      expect(logDescription.args.royaltyCut).to.eq(100)
      expect(logDescription.args.metadataId).to.eq('metadata')
      expect(logDescription.args.timestamp).to.exist
    })

    it('should be able to get royalty info', async function () {
      const info = await tripcipERC721.royaltyInfo(0, 50000, [])
      expect(info[0]).to.equal(minterAddress.address)
      expect(info[1].toString()).to.equal('500')
    })
  })

  describe('#tokenURI', () => {
    it('should be able to get token URI', async function () {
      expect(await tripcipERC721.tokenURI(0)).to.equal('https://test.url/0')
    })
  })
})

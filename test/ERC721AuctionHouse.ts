/* eslint-disable @typescript-eslint/no-extra-semi */
import chai, { expect } from 'chai'
import asPromised from 'chai-as-promised'
import { ethers } from 'hardhat'
import { ERC721AuctionHouse, BadBidder, TestERC721, BadERC721, UltrareumERC721 } from '../typechain'
import { formatUnits } from 'ethers/lib/utils'
import {BigNumber, BigNumberish, Contract, Overrides, Signer} from 'ethers'
import {
  deployBidder,
  deployMainNFT,
  deployOtherNFTs,
  deployWETH,
  ONE_ETH,
  revert,
  TWO_ETH,
} from './utils'

chai.use(asPromised)

describe('ERC721AuctionHouse', () => {
  let weth: Contract
  let badERC721: BadERC721
  let testERC721: TestERC721
  let ultrareumERC721: UltrareumERC721

  beforeEach(async () => {
    await ethers.provider.send('hardhat_reset', [])
    const nfts = await deployOtherNFTs()
    weth = await deployWETH()
    ultrareumERC721 = await deployMainNFT()
    badERC721 = nfts.bad
    testERC721 = nfts.test

    await ultrareumERC721.mint(100, '')
  })

  async function deploy(): Promise<ERC721AuctionHouse> {
    const AuctionHouse = await ethers.getContractFactory('ERC721AuctionHouse')
    const auctionHouse = await AuctionHouse.deploy(1000, 1000, weth.address, true)

    return auctionHouse as ERC721AuctionHouse
  }

  function getStartEndDates () {
    // Start date is 1st of Jan 2050
    // End date is 8th of Jan 2050

    const startDate = new Date(Date.parse('2050-01-01'))
    const endDate = new Date(startDate.getTime()+(7*24*60*60*1000)); // Plus 7 days

    const startDateTimestamp = startDate.getTime() / 1000
    const endDateTimestamp = endDate.getTime() / 1000

    return {
      startDate: startDateTimestamp,
      endDate: endDateTimestamp
    }
  }

  async function createAuction(
    auctionHouse: ERC721AuctionHouse,
    currency = '0x0000000000000000000000000000000000000000'
  ) {
    const tokenId = 0
    const { startDate, endDate } = getStartEndDates()

    const reservePrice = BigNumber.from(10).pow(18).div(2)
    const instantBuyPrice = BigNumber.from(10).pow(18).div(2)

    await auctionHouse.createAuction(
      tokenId,
      ultrareumERC721.address,
      startDate,
      endDate,
      reservePrice,
      instantBuyPrice,
      currency
    )
  }

  describe('#constructor', () => {
    it('should be able to deploy', async () => {
      const AuctionHouse = await ethers.getContractFactory('ERC721AuctionHouse')
      const auctionHouse = await AuctionHouse.deploy(200, 100, weth.address, true)
      expect(await auctionHouse.getServiceCut()).to.eq(200, 'initial cut should equal 100')
      expect(await auctionHouse.getInitialCut()).to.eq(100, 'service cut should equal 200')
      expect(await auctionHouse.minBidIncrementPercentage()).to.eq(
        5,
        'minBidIncrementPercentage should equal 5%'
      )
    })
  })

  const blockTimestampStartDate = 2524608000

  describe('#nativeUsed', () => {
    it('should revert if native currency is not allowed', async () => {
      await ethers.provider.send('evm_setNextBlockTimestamp', [blockTimestampStartDate])

      const AuctionHouse = await ethers.getContractFactory('ERC721AuctionHouse')
      const auctionHouse = await AuctionHouse.deploy(200, 100, weth.address, false)
      const { startDate, endDate } = getStartEndDates()

      await expect(
        auctionHouse.createAuction(
          0,
          ultrareumERC721.address,
          startDate,
          endDate,
          10,
          10,
          '0x0000000000000000000000000000000000000000'
        )
      ).eventually.rejectedWith(revert`Not allowed currency`)
    })
  })

  describe('#serviceCut', () => {
    let auctionHouse: Contract

    beforeEach(async () => {
      const AuctionHouse = await ethers.getContractFactory('ERC721AuctionHouse')
      auctionHouse = await AuctionHouse.deploy(200, 100, weth.address, true)
    })

    describe('getServiceCut', () => {
      it('should revert if the caller is not owner', async () => {
        const [_, other] = await ethers.getSigners()
        await expect(auctionHouse.connect(other).getServiceCut()).eventually.rejectedWith(
          revert`Ownable: caller is not the owner`
        )
      })

      it('should return service cut if the caller is owner', async () => {
        const [admin] = await ethers.getSigners()
        expect(await auctionHouse.connect(admin).getServiceCut()).to.equal(200)
      })
    })

    describe('setServiceCut', () => {
      it('should revert if the caller is not owner', async () => {
        const [_, other] = await ethers.getSigners()
        await expect(auctionHouse.connect(other).setServiceCut(10)).eventually.rejectedWith(
          revert`Ownable: caller is not the owner`
        )
      })

      it('should set service cut if the caller is owner', async () => {
        const [admin] = await ethers.getSigners()
        await auctionHouse.connect(admin).setServiceCut(10)
        expect(await auctionHouse.connect(admin).getServiceCut()).to.equal(10)
      })
    })
  })

  describe('#initialCut', () => {
    let auctionHouse: Contract

    beforeEach(async () => {
      const AuctionHouse = await ethers.getContractFactory('ERC721AuctionHouse')
      auctionHouse = await AuctionHouse.deploy(200, 100, weth.address, true)
    })

    describe('getInitialCut', () => {
      it('should revert if the caller is not owner', async () => {
        const [_, other] = await ethers.getSigners()
        await expect(auctionHouse.connect(other).getInitialCut()).eventually.rejectedWith(
          revert`Ownable: caller is not the owner`
        )
      })

      it('should return initial cut if the caller is owner', async () => {
        const [admin] = await ethers.getSigners()
        expect(await auctionHouse.connect(admin).getInitialCut()).to.equal(100)
      })
    })

    describe('setInitialCut', () => {
      it('should revert if the caller is not owner', async () => {
        const [_, other] = await ethers.getSigners()
        await expect(auctionHouse.connect(other).setInitialCut(10)).eventually.rejectedWith(
          revert`Ownable: caller is not the owner`
        )
      })

      it('should set initial cut if the caller is owner', async () => {
        const [admin] = await ethers.getSigners()
        await auctionHouse.connect(admin).setInitialCut(10)
        expect(await auctionHouse.connect(admin).getInitialCut()).to.equal(10)
      })
    })
  })

  describe('#createAuction', () => {
    let auctionHouse: ERC721AuctionHouse
    beforeEach(async () => {
      auctionHouse = await deploy()
      await ultrareumERC721.approve(auctionHouse.address, 0)
    })

    it('should revert if the token contract does not support the ERC721 interface', async () => {
      const { startDate, endDate } = getStartEndDates()
      const reservePrice = BigNumber.from(10).pow(18).div(2)
      const instantBuyPrice = BigNumber.from(10).pow(18).div(2)

      await expect(
        auctionHouse.createAuction(
          0,
          badERC721.address,
          startDate,
          endDate,
          reservePrice,
          instantBuyPrice,
          '0x0000000000000000000000000000000000000000'
        )
      ).eventually.rejectedWith(revert`tokenContract does not support ERC721 interface`)
    })

    it('should revert if the token ID does not exist', async () => {
      const tokenId = 999
      const { startDate, endDate } = getStartEndDates()
      const reservePrice = BigNumber.from(10).pow(18).div(2)
      const instantBuyPrice = BigNumber.from(10).pow(18).div(2)
      const [admin, _] = await ethers.getSigners()

      await expect(
        auctionHouse
          .connect(admin)
          .createAuction(
            tokenId,
            ultrareumERC721.address,
            startDate,
            endDate,
            reservePrice,
            instantBuyPrice,
            '0x0000000000000000000000000000000000000000'
          )
      ).eventually.rejectedWith(revert`ERC721: owner query for nonexistent token`)
    })

    it('should create an auction', async () => {
      const tokenOwner = await ultrareumERC721.ownerOf(0)

      await ultrareumERC721.approve(auctionHouse.address, 0)
      await createAuction(auctionHouse)

      const createdAuction = await auctionHouse.auctions(0)

      const startDate = new Date(createdAuction.startDate.toNumber() * 1000)
      const endDate = new Date(createdAuction.endDate.toNumber() * 1000)

      expect(startDate.toISOString()).to.eq('2050-01-01T00:00:00.000Z')
      expect(endDate.toISOString()).to.eq('2050-01-08T00:00:00.000Z')

      expect(createdAuction.reservePrice).to.eq(BigNumber.from(10).pow(18).div(2))
      expect(createdAuction.tokenOwner).to.eq(tokenOwner)
    })

    it('should emit an AuctionCreated event', async () => {
      const [_] = await ethers.getSigners()

      const block = await ethers.provider.getBlockNumber()
      await ultrareumERC721.approve(auctionHouse.address, 0)
      await createAuction(auctionHouse)
      const currAuction = await auctionHouse.auctions(0)
      const events = await auctionHouse.queryFilter(
        auctionHouse.filters.AuctionCreated(null, null, null, null, null, null, null),
        block
      )
      expect(events.length).eq(1)
      const logDescription = auctionHouse.interface.parseLog(events[0])
      expect(logDescription.name).to.eq('AuctionCreated')
      // TODO: fix me expect(logDescription.args.duration).to.eq(currAuction.duration)
      expect(logDescription.args.reservePrice).to.eq(currAuction.reservePrice)
      expect(logDescription.args.tokenOwner).to.eq(currAuction.tokenOwner)
      expect(logDescription.args.auctionCurrency).to.eq(ethers.constants.AddressZero)
    })
  })

  describe('#setAuctionReservePrice', () => {
    let auctionHouse: ERC721AuctionHouse
    let admin: Signer
    let creator: Signer
    let bidder: Signer

    beforeEach(async () => {
      ;[admin, creator, bidder] = await ethers.getSigners()
      auctionHouse = (await deploy()).connect(admin) as ERC721AuctionHouse
      ultrareumERC721.approve(auctionHouse.address, 0)
      await ethers.provider.send('evm_setNextBlockTimestamp', [blockTimestampStartDate])
      await createAuction(auctionHouse.connect(admin))
    })

    it('should revert if the auctionHouse does not exist', async () => {
      await expect(auctionHouse.setAuctionReservePrice(1, TWO_ETH)).eventually.rejectedWith(
        revert`Auction doesn't exist`
      )
    })

    it('should revert if not called by owner', async () => {
      await expect(
        auctionHouse.connect(bidder).setAuctionReservePrice(0, TWO_ETH)
      ).eventually.rejectedWith(revert`Must be token owner`)
    })

    it('should revert if the auction has already started', async () => {
      await auctionHouse.setAuctionReservePrice(0, TWO_ETH)
      await auctionHouse.connect(bidder).createBid(0, TWO_ETH, { value: TWO_ETH })
      await expect(auctionHouse.setAuctionReservePrice(0, ONE_ETH)).eventually.rejectedWith(
        revert`Auction has already started`
      )
    })

    it('should set the auction reserve price', async () => {
      await auctionHouse.setAuctionReservePrice(0, TWO_ETH)

      expect((await auctionHouse.auctions(0)).reservePrice).to.eq(TWO_ETH)
    })

    it('should set the auction reserve price when called by the token owner', async () => {
      await auctionHouse.connect(admin).setAuctionReservePrice(0, TWO_ETH)

      expect((await auctionHouse.auctions(0)).reservePrice).to.eq(TWO_ETH)
    })

    it('should emit an AuctionReservePriceUpdated event', async () => {
      const block = await ethers.provider.getBlockNumber()
      await auctionHouse.setAuctionReservePrice(0, TWO_ETH)
      const events = await auctionHouse.queryFilter(
        auctionHouse.filters.AuctionReservePriceUpdated(null, null, null, null),
        block
      )
      expect(events.length).eq(1)
      const logDescription = auctionHouse.interface.parseLog(events[0])

      expect(logDescription.args.reservePrice).to.eq(TWO_ETH)
    })
  })

  describe('#createBid', () => {
    let auctionHouse: ERC721AuctionHouse
    let admin: Signer
    let bidderA: Signer
    let bidderB: Signer

    beforeEach(async () => {
      ;[admin, bidderA, bidderB] = await ethers.getSigners()
      auctionHouse = (await (await deploy()).connect(bidderA)) as ERC721AuctionHouse
      await ultrareumERC721.approve(auctionHouse.address, 0)
      await ethers.provider.send('evm_setNextBlockTimestamp', [blockTimestampStartDate])
      await createAuction(auctionHouse.connect(admin))
    })

    it('should revert if the specified auction does not exist', async () => {
      await expect(auctionHouse.createBid(11111, ONE_ETH)).eventually.rejectedWith(
        revert`Auction doesn't exist`
      )
    })

    it('should revert if the bid is less than the reserve price', async () => {
      await expect(auctionHouse.createBid(0, 0, { value: 0 })).eventually.rejectedWith(
        revert`Must send at least reservePrice`
      )
    })

    describe('first bid', () => {
      it('should set the first bid time', async () => {
        const startBidTime = blockTimestampStartDate + 100

        await ethers.provider.send('evm_setNextBlockTimestamp', [startBidTime])
        await auctionHouse.createBid(0, ONE_ETH, {
          value: ONE_ETH,
        })

        expect((await auctionHouse.auctions(0)).firstBidTime).to.eq(startBidTime)
      })

      it('should store the transferred ETH as WETH', async () => {
        await auctionHouse.createBid(0, ONE_ETH, {
          value: ONE_ETH,
        })
        expect(await weth.balanceOf(auctionHouse.address)).to.eq(ONE_ETH)
      })

      // TODO: fix me
      // it("should not update the auction's duration", async () => {
      //   const beforeDuration = (await auctionHouse.auctions(0)).duration
      //   await auctionHouse.createBid(0, ONE_ETH, {
      //     value: ONE_ETH,
      //   })
      //   const afterDuration = (await auctionHouse.auctions(0)).duration
      //
      //   expect(beforeDuration).to.eq(afterDuration)
      // })

      it("should store the bidder's information", async () => {
        await auctionHouse.createBid(0, ONE_ETH, {
          value: ONE_ETH,
        })
        const currAuction = await auctionHouse.auctions(0)

        expect(currAuction.bidder).to.eq(await bidderA.getAddress())
        expect(currAuction.amount).to.eq(ONE_ETH)
      })

      it('should emit an AuctionBid event', async () => {
        const block = await ethers.provider.getBlockNumber()

        await auctionHouse.createBid(0, ONE_ETH, {
          value: ONE_ETH,
        })
        const events = await auctionHouse.queryFilter(
          auctionHouse.filters.AuctionBid(null, null, null, null, null, null, null),
          block
        )
        expect(events.length).eq(1)
        const logDescription = auctionHouse.interface.parseLog(events[0])

        expect(logDescription.name).to.eq('AuctionBid')
        expect(logDescription.args.auctionId).to.eq(0)
        expect(logDescription.args.sender).to.eq(await bidderA.getAddress())
        expect(logDescription.args.value).to.eq(ONE_ETH)
        expect(logDescription.args.firstBid).to.eq(true)
      })
    })

    describe('second bid', () => {
      beforeEach(async () => {
        auctionHouse = auctionHouse.connect(bidderB) as ERC721AuctionHouse
        await auctionHouse.connect(bidderA).createBid(0, ONE_ETH, { value: ONE_ETH })
      })

      it('should revert if the bid is smaller than the last bid + minBid', async () => {
        await expect(
          auctionHouse.createBid(0, ONE_ETH.add(1), {
            value: ONE_ETH.add(1),
          })
        ).eventually.rejectedWith(
          revert`Must send more than last bid by minBidIncrementPercentage amount`
        )
      })

      it('should refund the previous bid', async () => {
        const beforeBalance = await ethers.provider.getBalance(await bidderA.getAddress())
        const beforeBidAmount = (await auctionHouse.auctions(0)).amount
        await auctionHouse.createBid(0, TWO_ETH, {
          value: TWO_ETH,
        })
        const afterBalance = await ethers.provider.getBalance(await bidderA.getAddress())

        expect(afterBalance).to.eq(beforeBalance.add(beforeBidAmount))
      })

      it('should not update the firstBidTime', async () => {
        const firstBidTime = (await auctionHouse.auctions(0)).firstBidTime
        await auctionHouse.createBid(0, TWO_ETH, {
          value: TWO_ETH,
        })
        expect((await auctionHouse.auctions(0)).firstBidTime).to.eq(firstBidTime)
      })

      it('should transfer the bid to the contract and store it as WETH', async () => {
        await auctionHouse.createBid(0, TWO_ETH, {
          value: TWO_ETH,
        })

        expect(await weth.balanceOf(auctionHouse.address)).to.eq(TWO_ETH)
      })

      it('should update the stored bid information', async () => {
        await auctionHouse.createBid(0, TWO_ETH, {
          value: TWO_ETH,
        })

        const currAuction = await auctionHouse.auctions(0)

        expect(currAuction.amount).to.eq(TWO_ETH)
        expect(currAuction.bidder).to.eq(await bidderB.getAddress())
      })

      // TODO: fix me
      // it('should not extend the duration of the bid if outside of the time buffer', async () => {
      //   const beforeDuration = (await auctionHouse.auctions(0)).duration
      //   await auctionHouse.createBid(0, TWO_ETH, {
      //     value: TWO_ETH,
      //   })
      //   const afterDuration = (await auctionHouse.auctions(0)).duration
      //   expect(beforeDuration).to.eq(afterDuration)
      // })

      it('should emit an AuctionBid event', async () => {
        const block = await ethers.provider.getBlockNumber()
        await auctionHouse.createBid(0, TWO_ETH, {
          value: TWO_ETH,
        })
        const events = await auctionHouse.queryFilter(
          auctionHouse.filters.AuctionBid(null, null, null, null, null, null, null),
          block
        )
        expect(events.length).eq(2)
        const logDescription = auctionHouse.interface.parseLog(events[1])

        expect(logDescription.name).to.eq('AuctionBid')
        expect(logDescription.args.sender).to.eq(await bidderB.getAddress())
        expect(logDescription.args.value).to.eq(TWO_ETH)
        expect(logDescription.args.firstBid).to.eq(false)
      })

      // TODO: fix me
      // describe('last minute bid', () => {
      //   beforeEach(async () => {
      //     const currAuction = await auctionHouse.auctions(0)
      //     await ethers.provider.send('evm_setNextBlockTimestamp', [
      //       currAuction.firstBidTime.add(currAuction.duration).sub(1).toNumber(),
      //     ])
      //   })
      //   it('should extend the duration of the bid if inside of the time buffer', async () => {
      //     const beforeDuration = (await auctionHouse.auctions(0)).duration
      //     await auctionHouse.createBid(0, TWO_ETH, {
      //       value: TWO_ETH,
      //     })
      //
      //     const currAuction = await auctionHouse.auctions(0)
      //     expect(currAuction.duration).to.eq(
      //       beforeDuration.add(await auctionHouse.timeBuffer()).sub(1)
      //     )
      //   })
      //   it('should emit an AuctionBid event', async () => {
      //     const block = await ethers.provider.getBlockNumber()
      //     await auctionHouse.createBid(0, TWO_ETH, {
      //       value: TWO_ETH,
      //     })
      //     const events = await auctionHouse.queryFilter(
      //       auctionHouse.filters.AuctionBid(null, null, null, null, null, null, null),
      //       block
      //     )
      //     expect(events.length).eq(2)
      //     const logDescription = auctionHouse.interface.parseLog(events[1])
      //
      //     expect(logDescription.name).to.eq('AuctionBid')
      //     expect(logDescription.args.sender).to.eq(await bidderB.getAddress())
      //     expect(logDescription.args.value).to.eq(TWO_ETH)
      //     expect(logDescription.args.firstBid).to.eq(false)
      //     expect(logDescription.args.extended).to.eq(true)
      //   })
      // })
      // describe('late bid', () => {
      //   beforeEach(async () => {
      //     const currAuction = await auctionHouse.auctions(0)
      //     await ethers.provider.send('evm_setNextBlockTimestamp', [
      //       currAuction.firstBidTime.add(currAuction.duration).add(1).toNumber(),
      //     ])
      //   })
      //
      //   it('should revert if the bid is placed after expiry', async () => {
      //     await expect(
      //       auctionHouse.createBid(0, TWO_ETH, {
      //         value: TWO_ETH,
      //       })
      //     ).eventually.rejectedWith(revert`Auction expired`)
      //   })
      // })
    })
  })

  describe('#cancelAuction', () => {
    let auctionHouse: ERC721AuctionHouse
    let creator: Signer
    let bidder: Signer

    beforeEach(async () => {
      ;[creator, bidder] = await ethers.getSigners()
      auctionHouse = (await (await deploy()).connect(creator)) as ERC721AuctionHouse
      ultrareumERC721.approve(auctionHouse.address, 0)
      await createAuction(auctionHouse.connect(creator))
    })

    it('should revert if the auction does not exist', async () => {
      await expect(auctionHouse.cancelAuction(12213)).eventually.rejectedWith(
        revert`Auction doesn't exist`
      )
    })

    it('should revert if not called by a creator', async () => {
      await expect(auctionHouse.connect(bidder).cancelAuction(0)).eventually.rejectedWith(
        `Can only be called by auction creator`
      )
    })

    // TODO: fix me
    // it('should revert if the auction has already begun', async () => {
    //   await auctionHouse.connect(bidder).createBid(0, ONE_ETH, { value: ONE_ETH })
    //   await expect(auctionHouse.cancelAuction(0)).eventually.rejectedWith(
    //     revert`Can't cancel an auction once it's begun`
    //   )
    // })

    it('should be callable by the creator', async () => {
      await auctionHouse.cancelAuction(0)

      const auctionResult = await auctionHouse.auctions(0)

      expect(auctionResult.amount.toNumber()).to.eq(0)
      // TODO: fix me expect(auctionResult.duration.toNumber()).to.eq(0)
      expect(auctionResult.firstBidTime.toNumber()).to.eq(0)
      expect(auctionResult.reservePrice.toNumber()).to.eq(0)
      expect(auctionResult.tokenOwner).to.eq(ethers.constants.AddressZero)
      expect(auctionResult.bidder).to.eq(ethers.constants.AddressZero)
      expect(auctionResult.auctionCurrency).to.eq(ethers.constants.AddressZero)

      expect(await ultrareumERC721.ownerOf(0)).to.eq(await creator.getAddress())
    })

    it('should emit an AuctionCanceled event', async () => {
      const block = await ethers.provider.getBlockNumber()
      await auctionHouse.cancelAuction(0)
      const events = await auctionHouse.queryFilter(
        auctionHouse.filters.AuctionCanceled(null, null, null, null),
        block
      )
      expect(events.length).eq(1)
      const logDescription = auctionHouse.interface.parseLog(events[0])

      expect(logDescription.args.tokenId.toNumber()).to.eq(0)
      expect(logDescription.args.tokenOwner).to.eq(await creator.getAddress())
      expect(logDescription.args.tokenContract).to.eq(ultrareumERC721.address)
    })
  })

  describe('#endAuction', () => {
    let auctionHouse: ERC721AuctionHouse
    let creator: Signer
    let bidder: Signer
    let other: Signer
    let badBidder: BadBidder

    beforeEach(async () => {
      ;[creator, bidder, other] = await ethers.getSigners()
      auctionHouse = (await (await deploy()).connect(creator)) as ERC721AuctionHouse
      ultrareumERC721.approve(auctionHouse.address, 0)
      await createAuction(auctionHouse.connect(creator))
      badBidder = await deployBidder(auctionHouse.address)
    })

    it('should revert if the auction does not exist', async () => {
      await expect(auctionHouse.endAuction(1110)).eventually.rejectedWith(
        revert`Auction doesn't exist`
      )
    })

    it('should revert if the auction has not begun', async () => {
      await expect(auctionHouse.endAuction(0)).eventually.rejectedWith(revert`Auction hasn't begun`)
    })

    // it('should revert if the auction has not completed', async () => {
    //   await auctionHouse.createBid(0, ONE_ETH, {
    //     value: ONE_ETH,
    //   })
    //
    //   await expect(auctionHouse.endAuction(0)).eventually.rejectedWith(
    //     revert`Auction hasn't completed`
    //   )
    // })

    // TODO: fix me
    // it('should cancel the auction if the winning bidder is unable to receive NFTs', async () => {
    //   await badBidder.placeBid(0, TWO_ETH, { value: TWO_ETH })
    //   const endTime =
    //     (await auctionHouse.auctions(0)).duration.toNumber() +
    //     (await auctionHouse.auctions(0)).firstBidTime.toNumber()
    //   await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1])
    //
    //   await auctionHouse.endAuction(0)
    //
    //   expect(await ultrareumERC721.ownerOf(0)).to.eq(await creator.getAddress())
    //   expect(await ethers.provider.getBalance(badBidder.address)).to.eq(TWO_ETH)
    // })

    // TODO: fix me
    // describe('ETH auction', () => {
    //   beforeEach(async () => {
    //     await auctionHouse.connect(bidder).createBid(0, ONE_ETH, { value: ONE_ETH })
    //     const endTime =
    //       (await auctionHouse.auctions(0)).duration.toNumber() +
    //       (await auctionHouse.auctions(0)).firstBidTime.toNumber()
    //     await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1])
    //   })
    //
    //   it('should transfer the NFT to the winning bidder', async () => {
    //     await auctionHouse.endAuction(0)
    //
    //     expect(await ultrareumERC721.ownerOf(0)).to.eq(await bidder.getAddress())
    //   })
    //
    //   // it('should pay the creator the remainder of the winning bid', async () => {
    //   //   const beforeBalance = await ethers.provider.getBalance(await creator.getAddress())
    //   //   await auctionHouse.endAuction(0)
    //   //   const creatorBalance = await ethers.provider.getBalance(await creator.getAddress())
    //   //   const wethBalance = await weth.balanceOf(await creator.getAddress())
    //   //   await expect(creatorBalance.sub(beforeBalance).add(wethBalance).toString()).to.eq(
    //   //     '999224056000000000'
    //   //   )
    //   // })
    //
    //   it('should emit an AuctionEnded event', async () => {
    //     const block = await ethers.provider.getBlockNumber()
    //     const auctionData = await auctionHouse.auctions(0)
    //     await auctionHouse.endAuction(0)
    //     const events = await auctionHouse.queryFilter(
    //       auctionHouse.filters.AuctionEnded(null, null, null, null, null, null, null),
    //       block
    //     )
    //     expect(events.length).eq(1)
    //     const logDescription = auctionHouse.interface.parseLog(events[0])
    //
    //     const creatorBalance = await ethers.provider.getBalance(await creator.getAddress())
    //
    //     expect(logDescription.args.tokenId).to.eq(0)
    //     expect(logDescription.args.tokenOwner).to.eq(auctionData.tokenOwner)
    //     expect(logDescription.args.winner).to.eq(auctionData.bidder)
    //     expect(logDescription.args.amount.toString()).to.eq('800000000000000000')
    //     expect(logDescription.args.auctionCurrency).to.eq(weth.address)
    //   })
    //
    //   it('should delete the auction', async () => {
    //     await auctionHouse.endAuction(0)
    //
    //     const auctionResult = await auctionHouse.auctions(0)
    //
    //     expect(auctionResult.amount.toNumber()).to.eq(0)
    //     expect(auctionResult.duration.toNumber()).to.eq(0)
    //     expect(auctionResult.firstBidTime.toNumber()).to.eq(0)
    //     expect(auctionResult.reservePrice.toNumber()).to.eq(0)
    //     expect(auctionResult.tokenOwner).to.eq(ethers.constants.AddressZero)
    //     expect(auctionResult.bidder).to.eq(ethers.constants.AddressZero)
    //     expect(auctionResult.auctionCurrency).to.eq(ethers.constants.AddressZero)
    //   })
    // })
  })
})

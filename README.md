# Ultrareum

## Getting started

```
cp .env.example .env
yarn
```

## Compile contracts

```
yarn compile
```

## Running tests

```
yarn test
```

## Deploying

```
yarn deploy-rinkeby
```

## Verifying

First set the arguments in `./arguments.js`

```shell
yarn run hardhat verify [address] --constructor-args arguments.js --network rinkeby
```

## Summary

There are 4 smart contracts:

- `./contracts/base/UltrareumERC721.sol` ERC721 with royalties ERC2981 standard
- `./contracts/base/UltrareumERC1155.sol` ERC1155 with royalties ERC2981 standard
- `./contracts/ERC721AuctionHouse.sol` Auction for ERC721
- `./contracts/ERC1155Marketplace.sol` Buying + selling for ERC1155

## NFT creation flow

1. API generates metadata object, sends the `metadataId` back to the frontend
2. Frontend calls `UltrareumERC721.mint` function with `uint256 royaltyCut` and `string calldata metadataId`
3. API is listening to the `Event Minted`, after frontend called `mint` the metadata in the API database now gets a `tokenId` for the association

## NFT auction flow

1. Frontend calls `ERC721AuctionHouse.createAuction` function with:
   - `uint256 tokenId` tokenId
   - `address tokenContract` UltrareumERC721 tokenContract
   - `uint256 startDate` startDate
   - `uint256 endDate` endDate
   - `uint256 reservePrice` reservePrice (minimum price)
   - `address auctionCurrency` address of the currency, depending if in contract constructor `nativeUsed` is set, it uses ETH or WETH

The ownership of the token is now transferred to the auction house smart contract, and held in escrow.

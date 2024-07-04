# Pixelaunch Contract Overview

PixelaunchNFT is an ERC721 token implementation with additional features for whitelist minting, public minting, and royalties.

## Key Features
- Whitelist and public minting phases
- Configurable mint prices and supply limits
- Royalty support (ERC2981)
- Pausable minting
- Customizable minting limits per transaction and per wallet

## Contract Structure

### Inheritance
- ERC721
- ERC721Enumerable
- ERC721Pausable
- ERC2981
- ReentrancyGuard
- Whitelistable
- Ownable

### Key State Variables
- MAX_SUPPLY: Maximum total supply of NFTs
- MAX_WHITELIST_SUPPLY: Maximum supply for whitelist minting
- RESERVED_SUPPLY: Number of NFTs reserved for a specific recipient
- mintStartTimestamp: Start time for minting
- whitelistMintDuration: Duration of whitelist minting phase
- publicMintPrice & whitelistMintPrice: Prices for public and whitelist minting
- mintFundsBeneficiary & royaltyFundsBeneficiary: Recipients of mint and royalty funds

### Main Functions
2. publicMint: Allows public minting of NFTs
3. whitelistMint: Allows whitelisted addresses to mint NFTs
5. Various setter functions for updating contract parameters (onlyOwner)

### Whitelist Management
- addWhitelistSpots: Adds addresses to the whitelist
- removeWhitelistSpots: Removes addresses from the whitelist
- clearWhitelistSpots: Clears all whitelist spots for an address

### Additional Features
- Pausable minting (pause/unpause functions)
- Customizable base URI for token metadata
- Royalty configuration (setDefaultRoyalty)


## Prerequisites
- Foundry
- Rust/Cargo
- Yarn
- Linux / MacOS / WSL 2


## Getting Started

Initialize
```sh
yarn
```

Make a copy of `.env.defaults` to `.env` and set the desired parameters. This file is git ignored.

Build and Test.

```sh
yarn
yarn build
yarn test
```

## Deploy & Verify
```sh
yarn deploy --network <network-name> --script <my-script-name>
```

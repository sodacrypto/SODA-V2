# `🥤 SODA V2`

V2 smart contracts and how to borrow DAI with BTC as a collateral on SODA.

## Description

This second version of SODA includes four files: 

- **SODABTC.sol** smart contract converts Bitcoin (BTC) to SODABTC (ERC-20) for providing it as a collateral on SODA.

- **SODADAI.sol** credit pool smart contract aggregates DAI; mints/burns/distributes SODADAI between the lenders.

- **SODADAO.sol** smart contract helps the lenders to interact with the credit pool smart contract.

- **Util.sol** contains helper functions for parsing prices and concatenating strings.

> V2 Release date: 07.12.2019

## How SODA V2 Works

After you register on https://www.soda.network and verify your email, SODA will gerenate a unique Bitcoin-address for you. The collateral need to be sent to this address in order to take out a loan. We are using a solution by BitGo* for generating multi-sig BTC-addresses for the borrowers. SODA controls an admin key and BitGo holds the backup key. ***Please keep in mind that SODA V2 is a custodial solution.***

**BitGo is a digital asset trust company and security company. They offer a multisignature Bitcoin wallet service, where keys are divided among a number of owners to manage risk.*

When the Bitcoins are received from you, we are minting SODABTC (ERC-20) token in 1:1 proportion. We are using this one in order to interact with the credit pool smart contract. We will automatically send SODABTC on your behalf as a collateral and request smart contract to issue a loan for you.

SODABTC have been sent. You have provided your collateral. Now we are using oracles by Provable** to request the price from the exchange to evaluate your collateral (SODA V2 uses HitBTC's BTC/DAI trading pair as a price feed).

***Provable (ex. Oraclize) is an oracle service for smart contracts and dApps.*

As long as the oracle's price request has been processed, this data is integrated into the transaction of issuing a loan. Smart contract will transfer your loan to a pre-registered ETH-address that is linked to your account. After that you will be able to withdraw the funds to any Ethereum-address: exchanges, wallets (Coinbase Wallet, MyEtherWallet, MyCrypto, MetaMask, others), hardware wallets (Trezor, Ledger, KeepKey, others) etc.

## Credits

👨‍💻 Dan Gavrilin (CTO of SODA)

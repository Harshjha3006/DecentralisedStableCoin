# DecentralisedStableCoin
This is an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin
 It is designed to maintain 1 dollar == 1 DSC peg
 Collateral : ETH(Exogenous)
 It is similiar to DAI if it had no governance,no fees and was only backed by wEth
 My StableCoin is kept overcollateralized meaning the value of all collateral > value of all DSC at all points of time
 This coin is loosely based on the MakerDAO system

## Layout of Contracts
This project consist of mainly 2 contracts 
 * DecentralisedStableCoin.sol
    This is the ERC20 implementation of my stablecoin which is meant to be governed by DSCEngine.sol
 * DSCEngine.sol
     It is the owner of the DecentralisedStableCoin.sol
     It is the main contract that handles the minting and burning of the stablecoin.
     It also handles the depositing and borrowing of collateral

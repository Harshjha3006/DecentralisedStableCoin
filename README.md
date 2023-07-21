# DecentralisedStableCoin
This is an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin 
 <br>
 It is designed to maintain 1 dollar == 1 DSC peg 
 <br>
 Collateral : ETH(Exogenous) 
 <br>
 It is similiar to DAI if it had no governance,no fees and was only backed by wEth
 <br>
 My StableCoin is kept overcollateralized meaning the value of all collateral > value of all DSC at all points of time
 <br>
 This coin is loosely based on the MakerDAO system

## Layout of Contracts
This project consist of mainly 2 contracts <br>
 * ### DecentralisedStableCoin.sol
    This is the ERC20 implementation of my stablecoin which is meant to be governed by DSCEngine.sol <br>
 * ### DSCEngine.sol 
     It is the owner of the DecentralisedStableCoin.sol <br>
     It is the main contract that handles the minting and burning of the stablecoin. <br>
     It also handles the depositing and borrowing of collateral <br>

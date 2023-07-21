// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
pragma solidity ^0.8.18;

// imports

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// interfaces, libraries, contracts

/**
 * @title DecentralisedStableCoin
 * @author Harsh Jha
 * Collateral : Exogenous (ETH)
 * Minting : Algorithmic
 * Relative Stability : Pegged to USD
 * This contract is meant to be governed by DSCEngine.sol . it is just meant to be the ERC20 implementation of our StableCoin
 */
contract DecentralisedStableCoin is ERC20Burnable, Ownable {
  // errors

  error DecentralisedStableCoin__MustBeAboveZero();
  error DecentralisedStableCoin__BurnAmountExceedsBalance();
  error DecentralisedStableCoin__NotZeroAddress();

  // Layout of Functions:
  // constructor
  constructor() ERC20("DecentralisedStableCoin", "DSC") {}

  // Functions
  function burn(uint256 _amount) public override onlyOwner {
    if (_amount <= 0) {
      revert DecentralisedStableCoin__MustBeAboveZero();
    }
    uint256 balance = balanceOf(msg.sender);
    if (balance < _amount) {
      revert DecentralisedStableCoin__BurnAmountExceedsBalance();
    }
    super.burn(_amount);
  }

  function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
    if (_to == address(0)) {
      revert DecentralisedStableCoin__NotZeroAddress();
    }
    if (_amount < 0) {
      revert DecentralisedStableCoin__MustBeAboveZero();
    }
    _mint(_to, _amount);
    return true;
  }
}

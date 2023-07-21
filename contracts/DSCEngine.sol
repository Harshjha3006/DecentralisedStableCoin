// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
//imports
import "./DecentralisedStableCoin.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSC Engine
 * @author Harsh Jha
 * It is designed to maintain 1 token == 1 dollar peg
 * the stablecoin has the following properties :
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically stable
 * It is similiar to DAI if it had no governance,no fees and was only backed by wEth
 * Our DSC should be overcollateralized meaning the value of all collateral > value of all DSC at all points of time
 * @notice This contract is meant to be the core of the DSC system . It handles the logic of mining and redeeming DSC as well as
 *  depositiing and withdrawing collateral
 * @notice This is loosely based on MakerDAO DSS (DAI) system
 *
 */
contract DSCEngine is ReentrancyGuard {
  //Errors

  error DSCEngine__AmountShouldBeMoreThanZero();
  error DSCEngine__TokenNotAllowed();
  error DSCEngine__TokenAddressesLengthShouldBeEqualToPriceFeedAddressesLength();
  error DSCEngine__TransferFailed();
  error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
  error DSCEngine__MintFailed();
  error DSCEngine__HealthFactorOk();
  error DSCEngine__HealthFactorNotImproved();

  // State Variables

  mapping(address token => address priceFeed) private s_priceFeeds;
  mapping(address user => mapping(address token => uint256 amount))
    private s_collateralDeposited;
  mapping(address user => uint256 amount) s_DSCminted;
  DecentralisedStableCoin private immutable i_dsc;
  uint256 private constant MIN_HEALTH_FACTOR = 1e18;
  address[] private s_collateralTokens;
  uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% Collateralization
  uint256 private constant LIQUIDATION_BONUS = 10;

  // Events

  event CollateralDeposited(
    address indexed user,
    address indexed token,
    uint256 indexed amount
  );
  event CollateralRedeemed(
    address indexed redeemedFrom,
    address indexed redeemedTo,
    address indexed token,
    uint256 amount
  );

  // Modifiers

  modifier moreThanZero(uint256 amount) {
    if (amount <= 0) {
      revert DSCEngine__AmountShouldBeMoreThanZero();
    }
    _;
  }
  modifier isTokenAllowed(address tokenAddress) {
    if (s_priceFeeds[tokenAddress] == address(0)) {
      revert DSCEngine__TokenNotAllowed();
    }
    _;
  }

  // Constructor
  constructor(
    address[] memory tokenAddresses,
    address[] memory priceFeedAddresses,
    address dscAddress
  ) {
    if (tokenAddresses.length != priceFeedAddresses.length) {
      revert DSCEngine__TokenAddressesLengthShouldBeEqualToPriceFeedAddressesLength();
    }
    for (uint256 i = 0; i < tokenAddresses.length; i++) {
      s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
      s_collateralTokens.push(tokenAddresses[i]);
    }
    i_dsc = DecentralisedStableCoin(dscAddress);
  }

  /**
   *
   * @param tokenCollateralAddress The address of the token which is deposited as collateral
   * @param collateralAmount The amount of the collateral to be deposited
   * @param dscToMint The amount of the dsc To be minted
   * @notice This function will deposit collateral and mint dsc in one single transaction
   **/
  function depositCollateralAndMintDsc(
    address tokenCollateralAddress,
    uint256 collateralAmount,
    uint256 dscToMint
  ) external {
    depositCollateral(tokenCollateralAddress, collateralAmount);
    mintDsc(dscToMint);
  }

  /**
   * @notice follows CEI pattern
   * @param tokenAddress The address of the token to be deposited as collateral
   * @param amount The amount of token to be deposited as collateral
   */
  function depositCollateral(
    address tokenAddress,
    uint256 amount
  ) public moreThanZero(amount) isTokenAllowed(tokenAddress) nonReentrant {
    s_collateralDeposited[msg.sender][tokenAddress] += amount;
    emit CollateralDeposited(msg.sender, tokenAddress, amount);
    bool success = IERC20(tokenAddress).transferFrom(
      msg.sender,
      address(this),
      amount
    );
    if (!success) {
      revert DSCEngine__TransferFailed();
    }
  }

  /**
   * @param tokenCollateralAddress address of token to withdraw
   * @param collateralAmount amount of collateral to withdraw
   * @param dscAmount amount of dsc to burn
   * @notice This function burns dsc and redeems underlying collateral in one transaction
   */
  function redeemCollateralForDsc(
    address tokenCollateralAddress,
    uint256 collateralAmount,
    uint256 dscAmount
  ) external {
    burnDSC(dscAmount);
    redeemCollateral(tokenCollateralAddress, collateralAmount);
    // redeemCollateral checks for healthFactor
  }

  function redeemCollateral(
    address tokenCollateral,
    uint256 amount
  ) public moreThanZero(amount) nonReentrant {
    // below line will automatically revert if amount > balance
    _redeemCollateral(msg.sender, msg.sender, tokenCollateral, amount);
    _revertIfBreaksHealthFactor(msg.sender);
  }

  function mintDsc(uint256 amount) public moreThanZero(amount) {
    s_DSCminted[msg.sender] += amount;
    _revertIfBreaksHealthFactor(msg.sender);
    bool minted = i_dsc.mint(msg.sender, amount);
    if (!minted) {
      revert DSCEngine__MintFailed();
    }
  }

  function burnDSC(uint256 amount) public moreThanZero(amount) nonReentrant {
    _burnDsc(amount, msg.sender, msg.sender);
  }

  /**
   * @param collateral address of erc20 token which is to be liquidated from the user
   * @param user address of the user who is to be liquidated
   * @param debtToCover the amount of DSC you want to burn to improve user's health factor
   * @notice Liquidators get liquidation bonus
   * @notice this function assumes that the protocol is 200% overcollateralised
   */
  function liquidate(
    address collateral,
    address user,
    uint256 debtToCover
  ) external moreThanZero(debtToCover) nonReentrant {
    uint256 startingUserHealthFactor = _healthFactor(user);
    if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
      revert DSCEngine__HealthFactorOk();
    }
    uint256 tokenAmountFromDebt = getTokenAmountFromUsd(
      collateral,
      debtToCover
    );
    uint256 bonusCollateral = (tokenAmountFromDebt * LIQUIDATION_BONUS) / 100;
    uint256 totalCollateralToRedeem = tokenAmountFromDebt + bonusCollateral;
    _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
    _burnDsc(debtToCover, user, msg.sender);
    uint256 endingUserHealthFactor = _healthFactor(user);
    if (endingUserHealthFactor <= startingUserHealthFactor) {
      revert DSCEngine__HealthFactorNotImproved();
    }
    _revertIfBreaksHealthFactor(msg.sender);
  }

  function getHealthFactor() external view {}

  // internal functions
  /**
   *  @dev do not call these low level functions without checking if health factor is broken
   */

  function _burnDsc(uint256 amount, address onBehalfOf, address from) private {
    s_DSCminted[onBehalfOf] -= amount;
    bool success = IERC20(i_dsc).transferFrom(from, address(this), amount);
    if (!success) {
      revert DSCEngine__TransferFailed();
    }
    i_dsc.burn(amount);
  }

  function _redeemCollateral(
    address from,
    address to,
    address tokenCollateral,
    uint256 amount
  ) private {
    s_collateralDeposited[from][tokenCollateral] -= amount;
    emit CollateralRedeemed(from, to, tokenCollateral, amount);
    bool success = IERC20(tokenCollateral).transfer(to, amount);
    if (!success) {
      revert DSCEngine__TransferFailed();
    }
  }

  function _revertIfBreaksHealthFactor(address user) internal view {
    uint256 healthFactor = _healthFactor(user);
    if (healthFactor < MIN_HEALTH_FACTOR) {
      revert DSCEngine__BreaksHealthFactor(healthFactor);
    }
  }

  function _healthFactor(address user) internal view returns (uint256) {
    (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getUserInfo(
      user
    );
    if (totalDscMinted == 0) return type(uint256).max;
    uint256 totalCollateralAdjustedForThreshold = (totalCollateralValueInUsd *
      LIQUIDATION_THRESHOLD) / 100;
    return (totalCollateralAdjustedForThreshold * 1e18) / totalDscMinted;
  }

  // private view functions
  function _getUserInfo(
    address user
  )
    private
    view
    returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
  {
    totalDscMinted = s_DSCminted[user];
    totalCollateralValueInUsd = _getCollateral(user);
  }

  function _getCollateral(
    address user
  ) private view returns (uint256 totalCollateralValue) {
    for (uint256 i = 0; i < s_collateralTokens.length; i++) {
      address token = s_collateralTokens[i];
      uint256 amount = s_collateralDeposited[token][user];
      totalCollateralValue += getUsdValue(token, amount);
    }
  }

  function getTokenAmountFromUsd(
    address collateral,
    uint256 usdAmountInWei
  ) public view returns (uint256) {
    AggregatorV3Interface pricefeed = AggregatorV3Interface(
      s_priceFeeds[collateral]
    );
    (, int price, , , ) = pricefeed.latestRoundData();
    return ((usdAmountInWei * 1e18) / ((uint256)(price) * 1e10));
  }

  function getUsdValue(
    address token,
    uint256 amount
  ) public view returns (uint256) {
    AggregatorV3Interface priceFeed = AggregatorV3Interface(
      s_priceFeeds[token]
    );
    (, int price, , , ) = priceFeed.latestRoundData();
    return (uint256(price * 1e10) * amount) / 1e18;
  }
}

// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


/**
 * @title  DSCEngine
 * @author Kalyan
 * The system is desinged to be as minimal as possible, and have tokens maintain a 1 token == $1 peg.
 * This is a stablecoin with properties:
 * - Exogenous Collaterized
 * - Dollar Pegged
 * - Algorithmically Stable
 * 
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 * 
 * Our DSC system should always be "overcollaterized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 * 
 * @notice This contract is the core of the Decentralized Stablecoin System. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS (DAI) System
 */
contract DSCEngine is ReentrancyGuard {

    // Errors
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    // Types
    

    // State Variables
    DecentralizedStableCoin private immutable i_dsc;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collaterised
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    
    /// @dev Mapping of token address to price feed address
    mapping (address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping (address user => mapping (address collateralToken => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of DSC minted by user
    mapping (address user => uint256 amountDscMinted) private s_DSCMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutba
    address[] private s_collateralTokens;

    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    // Modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if(s_priceFeeds[token] == address(0)){
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    constructor(
        address[] memory tokenAddresses, 
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        uint256 len = tokenAddresses.length;
        for (uint256 i=0; i<len; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
            
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }


    ////////////////////////
    /// External Functions
    ///////////////////////

    function depositCollateralAndMintDsc() external {}

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
    */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) 
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {

        s_collateralDeposited[msg.sender][tokenCollateralAddress] = amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
            
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /*
     * @param amountDscToMint: The amount of DSC you want to mint 
     * You can only mint DSC if you have enough collateral
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc() external{}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////
    /// Private & Internal View Functions
    ///////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd); 
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns(uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////
    /// Public & External View Functions
    ///////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        uint256 tokenLen = s_collateralTokens.length;

        for (uint256 i=0; i< tokenLen; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend that they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
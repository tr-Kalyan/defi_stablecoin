// SPDX-License-Identifier: MIT
// Handler is going to narrow down the way we call function
// If no one is underwater, or if they are, liquidation is possible

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator wbtcUsdPriceFeed;

    uint256 public timesMintIsCalled;
    address[] usersWithCollateralDeposited;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        dsce = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
        wbtcUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
    }

    ///////////////////
    // Deposit Collateral
    ///////////////////
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // mint and approve
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);
    }

    ///////////////////
    // Mint DSC
    ///////////////////

    function mint(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collteralValueInUsd) = dsce.getAccountInformation(sender);
        // uint256 maxDscToMint = (collteralValueInUsd / 2) - totalDscMinted;

        // if (maxDscToMint < 0){
        //     return;
        // }

        // amount = bound(amount, 0 , maxDscToMint);
        // if(amount == 0){
        //     return;
        // }

        amount = bound(amount, 1, 1e30);
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    ///////////////////
    // Redeem Collateral
    ///////////////////

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

        if (amountCollateral == 0) {
            return;
        }

        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    ///////////////////
    // Burn DSC
    ///////////////////
    function burnDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        uint256 maxDscToBurn = dsc.balanceOf(sender);
        if (maxDscToBurn == 0) return;

        amount = bound(amount, 1, maxDscToBurn);

        vm.startPrank(sender);
        dsc.approve(address(dsce), amount); // needed for burnDsc
        dsce.burnDsc(amount);
        vm.stopPrank();
    }

    ///////////////////
    // LIQUIDATE
    ///////////////////
    function liquidate(uint256 collateralSeed, uint256 addressSeed, uint256 debtToCover) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address userToLiquidate = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

        if (dsce.getHealthFactor(userToLiquidate) >= 1e18) return; // not underwater

        debtToCover = bound(debtToCover, 1, dsc.balanceOf(msg.sender)); // liquidator must have DSC

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        dsce.liquidate(address(collateral), userToLiquidate, debtToCover);
    }

    ///////////////////
    // PRICE UPDATE
    ///////////////////
    function updateCollateralPrice(uint96 price, uint256 collateralSeed) public {
        // Bound to realistic range: $100 to $100,000
        price = uint96(bound(price, 100e8, 100_000e8));

        int256 intPrice = int256(uint256(price));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(collateral)));
        priceFeed.updateAnswer(intPrice);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }
}

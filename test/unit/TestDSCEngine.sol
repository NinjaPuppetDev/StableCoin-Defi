// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStablecoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract TestDSCEngine is Test {
    DeployDSCEngine deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;
    address btcUsdPriceFeed;

    uint256 amountToMint = 100 ether;
    uint256 amountToBurn = 20 ether;
    uint256 amountCollateral = 10 ether;
    uint256 collateralToCover = 20 ether;

    address public liquidator = makeAddr("liquidator");

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSCEngine();
        (dsc, engine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    address[] public tokenAddress;
    address[] public feedAddress;

    function testRevertTokenLengthDoesNotMach() public {
        tokenAddress.push(weth);
        feedAddress.push(ethUsdPriceFeed);
        feedAddress.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressMustBeTheSame.selector);
        new DSCEngine(tokenAddress, feedAddress, address(dsc));
    }

    /*//////////////////////////////////////////////////////////////
                               PRICE TEST
    //////////////////////////////////////////////////////////////*/

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30_000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;

        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NotEnoughCollateral.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralInUSd = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDSCMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedCollateralInUSd);
    }

    // Troublesome functions.

    function testCanMintDSC() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDSC(amountToMint);
        uint256 userMintedDSC = dsc.balanceOf(USER);
        assertEq(userMintedDSC, amountToMint);
    }

    function testUserCanBurnDSC() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDSC(amountToMint);
        dsc.approve(address(engine), amountToMint);
        engine.burnDSC(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);

        assertEq(userBalance, 0);
    }

    function testUserCanBurnAndRedeemCollateralForDToken() public depositedCollateral {
        vm.startPrank(USER);

        uint256 userCollateralBefore = engine.getCollateralBalanceOfUser(USER, weth);

        assertEq(userCollateralBefore, AMOUNT_COLLATERAL);

        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userCollateralAfter = engine.getCollateralBalanceOfUser(USER, weth);
        vm.stopPrank();
        assertEq(userCollateralAfter, 0);
    }

    function testUserCantMintZeroDSCAndRunAwayWithIt() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotEnoughCollateral.selector);
        engine.burnDSC(0);
        vm.stopPrank();
    }

    function testOtherUserCanNOTLiquidateTheUserBecauseHeIsOKE() public depositedCollateral {
        uint256 debtToCover = 5 ether;
        vm.startPrank(USER);
        engine.mintDSC(amountToMint);
        dsc.approve(address(engine), amountToBurn);

        // collateral value is less than DSC
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, debtToCover);

        vm.stopPrank();
    }

    modifier liquidation() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();

        uint256 newPrice = 18e8;

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(int256(newPrice));
        console.log("Updated ETH/USD Price:", newPrice);
        console.log("New health factor after price update:", engine.getHealthFactor(USER));

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDSC(weth, collateralToCover, amountToMint);
        dsc.approve(address(engine), amountToMint);
        engine.liquidate(weth, USER, amountToMint);
        vm.stopPrank();
        _;
    }

    function testLiquidationPayIsCorrect() public liquidation {
        uint256 liquidationWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = engine.getTokenAmountFromUsd(weth, amountToMint)
            + (
                engine.getTokenAmountFromUsd(weth, amountToMint) * engine.getLiquidationBonus()
                    / engine.getLiquidationPrecision()
            );
        console.log("Liquidator balance before liquidation:", ERC20Mock(weth).balanceOf(liquidator));

        console.log("Liquidation WETH Balance:", liquidationWethBalance);
        console.log("Expected WETH:", expectedWeth);
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidationWethBalance, hardCodedExpected);
        assertEq(liquidationWethBalance, expectedWeth);

        console.log("Actual health factor:", engine.getHealthFactor(USER));
        console.log("Expected health factor:", hardCodedExpected);
    }
}

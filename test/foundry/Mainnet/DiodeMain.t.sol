// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

//standard test libs
import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";

//librairies
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//Contract under test
import {Diode} from "../../../contracts/Diode.sol";
import {EulerStrat} from "../../../contracts/Strategies/Mainnet/EulerStrat.sol";

interface IEulerMarkets {
    function underlyingToEToken(address) external returns (address);
}

interface IEulerStrat {
    function deposit(address token, uint256 amount) external;
    function getSupplyAPY() external returns (uint256);
}

interface IEulerEToken {
    function deposit(uint, uint) external;
    function withdraw(uint, uint) external;
    function balanceOf(address) external returns (uint);
}

contract Diode_test_Mainnet is Test {

    using SafeERC20 for IERC20;

    //Variable for contract instance
    Diode private diode;
    EulerStrat private eulerStrat;

    // init users
    address random = 0x69217947EfBB9684C32BF2211185e6684412BEd6; // 19 stETH 
    address user1 = 0x1c1cc870115FDf86288cf38556c4da441699A0E2; // 50 stETH
    address user2 = 0x5ee50C69028CC6121982d6bf1aBf95ED10D57D15; // 1 stETH
    address user3 = 0x11fdBcf4FCD2AAc2397B7F7858877e2351C9b1E3; // 42 stETH

    // init tokens
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address LidoStETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; 

    // euler addresses
    address EULER_MAINNET_MARKETS = 0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3;
    IEulerMarkets markets = IEulerMarkets(EULER_MAINNET_MARKETS);

    constructor() { 
        
    }

    // Verify equality within difference
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            emit log_named_uint("Error: approx a == b not satisfied, accuracy difference ", expectedDiff);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    function setUp() public {

        uint256[2] memory cap;
        cap[0] = 30 * 10**18;
        cap[1] = 30 * 10**18;
        uint256 strikePrice = 1200 * 10**9;
        uint256 duration = 2629743; // 30.44 days UNIX time
        uint256 deltaPrice = 300 * 10**9;
        address chainlinkPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD price feed
/*         deal(LidoStETH, random, 20 ether);
        deal(LidoStETH, user1, 20 ether);
        deal(LidoStETH, user2, 20 ether);
        deal(LidoStETH, user3, 20 ether); */

        //Instantiate new contract instance
        diode = new Diode(
            strikePrice,
            LidoStETH,
            duration,
            block.timestamp,
            deltaPrice,
            chainlinkPriceFeed,
            1000,
            cap,
            "Diode_stETH",
            "DIO1"
        );

        //Instantiate new contract instance
        eulerStrat = new EulerStrat(
            LidoStETH,
            address(diode)
        );

        diode.setStrategy(address(eulerStrat));
    }

    function test_Diode_init() public {
        assertEq(diode.suppliedAsset(),                    0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        assertEq(diode.strikePrice(),                      1600 * 10**9);
        assertEq(diode.duration(),                         2629743);
        assertEq(diode.chainlinkPriceFeed(),               0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        assertEq((diode.finalTime() - diode.startTime()),  diode.duration());
        assertEq(diode.deltaPrice(),                       300 * 10**9);

        withinDiff(diode.startTime(),                      block.timestamp, 100);

        emit log_named_address("Diode contract address:",  address(diode));

        
    }

    function test_EulerStrat_init() public {
        assertEq(eulerStrat.underlyingToken(),             LidoStETH);
        assertEq(eulerStrat.owner(),                       address(diode));
        emit log_named_address("Euler contract address:",  address(eulerStrat));
        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(eulerStrat.underlyingToken()));
        emit log_named_address("eToken contract address:", address(eToken));

    }


    function test_Diode_DepositFunds() public {

        // +1 hour
        vm.warp(block.timestamp + 1 hours);

        // FTX deposit
        vm.startPrank(random);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 10 ether);

        (uint256 FTX_computedPriceRisk,
         uint256 FTX_alpha,
         uint256 FTX_standardizedPrice, 
         uint256 FTX_standardizedAmount) = diode.depositFunds(10 ether, false);

        vm.stopPrank();

        // + 15 days

        vm.warp(block.timestamp + 15 days);

/*         // user1 deposit
        vm.startPrank(user1);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 10 ether);

        
        (uint256 user1_computedPriceRisk,
         uint256 user1_alpha,
         uint256 user1_standardizedPrice, 
         uint256 user1_standardizedAmount) = diode.depositFunds(10 ether, true);

        vm.stopPrank(); */

        vm.warp(block.timestamp + 7 days);

        // user2 deposit

/*         vm.startPrank(user2);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 0.5 ether);

        
        (uint256 user2_computedPriceRisk,
         uint256 user2_alpha,
         uint256 user2_standardizedPrice, 
         uint256 user2_standardizedAmount) = diode.depositFunds(0.5 ether, true);

        vm.stopPrank(); */

        vm.warp(block.timestamp + 2 days);
        // user3 deposit

        vm.startPrank(user3);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 20 ether);
        
        (uint256 user3_computedPriceRisk,
         uint256 user3_alpha,
         uint256 user3_standardizedPrice, 
         uint256 user3_standardizedAmount) = diode.depositFunds(20 ether, true);

        vm.stopPrank();


        emit log_string("FTX results:");

        emit log_named_uint("computedPriceRisk", FTX_computedPriceRisk);
        emit log_named_uint("alpha:", FTX_alpha);
        emit log_named_uint("standardizedPrice:", FTX_standardizedPrice);
        emit log_named_uint("standardizedAmount:", FTX_standardizedAmount);

/*         emit log_string("user1 results:");

        emit log_named_uint("computedPriceRisk", user1_computedPriceRisk);
        emit log_named_uint("alpha:", user1_alpha);
        emit log_named_uint("standardizedPrice:", user1_standardizedPrice);
        emit log_named_uint("standardizedAmount:", user1_standardizedAmount); */

/*         emit log_string("user2 results:");

        emit log_named_uint("computedPriceRisk", user2_computedPriceRisk);
        emit log_named_uint("alpha:", user2_alpha);
        emit log_named_uint("standardizedPrice:", user2_standardizedPrice);
        emit log_named_uint("standardizedAmount:", user2_standardizedAmount); */

        emit log_string("user3 results:");

        emit log_named_uint("computedPriceRisk", user3_computedPriceRisk);
        emit log_named_uint("alpha:", user3_alpha);
        emit log_named_uint("standardizedPrice:", user3_standardizedPrice);
        emit log_named_uint("standardizedAmount:", user3_standardizedAmount);

        emit log_named_address("Owner of token 1:", diode.ownerOf(1));
        emit log_named_address("Owner of token 2:", diode.ownerOf(2));

        emit log_named_uint("Euler Strat Balance before:", eulerStrat.stratBalance());

        emit log_named_uint("expected APY longs:", diode.apyBoosterLong());
        emit log_named_uint("expected APY shorts:", diode.apyBoosterShort());

        vm.startPrank(address(diode));
        emit log_named_uint("get supply APY Euler:", eulerStrat.getSupplyAPY());
        eulerStrat.withdraw();
        vm.stopPrank();

        emit log_named_uint("Euler Strat Balance after:", eulerStrat.stratBalance());

    }


    function test_Diode_DepositAndWithdrawFunds() public {

        // +1 hour
        vm.warp(block.timestamp + 1 hours);

        // FTX deposit
        vm.startPrank(random);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 4 ether);

        (uint256 FTX_computedPriceRisk,
         uint256 FTX_alpha,
         uint256 FTX_standardizedPrice, 
         uint256 FTX_standardizedAmount) = diode.depositFunds(4 ether, true);

        vm.stopPrank();

        //////////////////////////////////////////////////////// + 15 days
        vm.warp(block.timestamp + 15 days);
        //////////////////////////////////////////////////////// 

        // user1 deposit
        vm.startPrank(user1);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 10 ether);

        
        (uint256 user1_computedPriceRisk,
         uint256 user1_alpha,
         uint256 user1_standardizedPrice, 
         uint256 user1_standardizedAmount) = diode.depositFunds(10 ether, false);

        vm.stopPrank();

        //////////////////////////////////////////////////////// + 7 days
        vm.warp(block.timestamp + 7 days);
        //////////////////////////////////////////////////////// 

        // user2 deposit
        vm.startPrank(user2);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 0.5 ether);

        
        (uint256 user2_computedPriceRisk,
         uint256 user2_alpha,
         uint256 user2_standardizedPrice, 
         uint256 user2_standardizedAmount) = diode.depositFunds(0.5 ether, true);

        vm.stopPrank();  

        //////////////////////////////////////////////////////// + 2 days
        vm.warp(block.timestamp + 2 days);
        //////////////////////////////////////////////////////// 

        // user3 deposit
        vm.startPrank(user3);

        IERC20(LidoStETH).safeApprove(0xCe71065D4017F316EC606Fe4422e11eB2c47c246, 20 ether);

        
        (uint256 user3_computedPriceRisk,
         uint256 user3_alpha,
         uint256 user3_standardizedPrice, 
         uint256 user3_standardizedAmount) = diode.depositFunds(20 ether, false);

        vm.stopPrank(); 

        //////////////////////////////////////////////////////// + 8 days
        vm.warp(block.timestamp + 8 days);
        //////////////////////////////////////////////////////// 

        vm.startPrank(user1);
        IERC20(diode.suppliedAsset()).safeTransfer(address(eulerStrat), 1 ether);
        vm.stopPrank();

        vm.prank(diode.owner());
        diode.closePool();

        //////////////////////////////////////////////////////// 
        //   GET REWARDS
        //////////////////////////////////////////////////////// 

        // FTX
        emit log_string("FTX initial data");
        emit log_named_uint("total Rewards:", diode.totalRewards());
        emit log_named_uint("total assets:", diode.totalDeposits());

        vm.startPrank(random);
        uint256 FTX_amount = diode.getReward(1);
        vm.stopPrank();

        // user 1
        vm.startPrank(user1);
        uint256 user1_amount = diode.getReward(2);
        vm.stopPrank();

        // user 2
        vm.startPrank(user2);
        uint256 user2_amount = diode.getReward(3);
        vm.stopPrank();  

        // user 3
        vm.startPrank(user3);
        uint256 user3_amount = diode.getReward(4);
        vm.stopPrank();

        emit log_named_uint("random amount:", FTX_amount);
        emit log_named_uint("user1 amount:", user1_amount);
        emit log_named_uint("user 2 amount:", user2_amount);
        emit log_named_uint("user 3 amount:", user3_amount);
        emit log_named_uint("remaining contract balance:", IERC20(diode.suppliedAsset()).balanceOf(address(diode)));

        emit log_named_uint("total longs:", diode.alphaLongs());
        emit log_named_uint("total shorts:", diode.alphaShorts());


    }


}
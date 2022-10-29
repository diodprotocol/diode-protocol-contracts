// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/safeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


interface AggregatorV3Interface {
    function latestRoundData() external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

interface IEulerMarkets {
    function underlyingToEToken(address) external returns (address);
}

interface IEulerStrat {
    function deposit(address token, uint256 amount) external;
    function withdraw() external returns (uint256);
}

//TODO: create factory
contract Diode is ERC721, Ownable {

    using SafeERC20 for IERC20;


    // -----------------
    //  State Variables
    // -----------------


    address public suppliedAsset;
    uint256 public strikePrice;
    address public chainlinkPriceFeed;
    uint256 public startTime;
    uint256 public finalTime;
    uint256 public duration;
    uint256 public longs;
    uint256 public shorts;
    uint256 public deltaPrice;
    uint256 public endPrice;
    uint256 public totalRewards;
    uint256 public tokenCount;
    address private eulerStratContract;
    bool public poolIsClosed;
    uint256 public totalDeposits;
    uint256 public totalReturnedFromStrat;


    struct UserDeposit {
        uint256 amount;
        uint256 timeStamp;
        // 9 decimals for assetPrice
        uint256 assetPrice;
        bool longOrShort;
        // 18 decimals for alpha
        uint256 alpha;
    }

    mapping(uint256 => UserDeposit) public tokenToPosition;


    // -----------------
    //    Constructor
    // -----------------


    /// @notice Initializes the Iode pool.
    /// @param _strikePrice strike price for the supplied asset at the end of duration of the pool, (base 9).
    /// @param _asset address of the asset supplied to the pool.
    /// @param _duration address of the convex Booster contract.
    /// @param _deltaPrice the risk factor used by the contract to scale the pricing risk (base 9)
    /// @param _chainlinkPriceFeed  contract address of the chainlink price feed for supplied asset.

    constructor(
    uint256 _strikePrice, 
    address _asset,
    uint256 _duration,
    uint256 _startTime,
    uint256 _deltaPrice,
    address _chainlinkPriceFeed,
    string memory _name,
    string memory _symbol) 
    ERC721(_name, _symbol)
    {
        suppliedAsset = _asset;
        strikePrice = _strikePrice;
        chainlinkPriceFeed = _chainlinkPriceFeed;
        duration = _duration;
        startTime = _startTime;
        finalTime = _startTime + _duration;
        deltaPrice = _deltaPrice;

    }


    // -----------------
    //    Functions
    // -----------------


    function setStrategy(address _strat) external onlyOwner {

        eulerStratContract = _strat;

    }

    function depositFunds(uint256 amount, bool longShort) public returns (
        uint256 _computedRisk, 
        uint256 _alpha, 
        uint256 _standardizedPrice, 
        uint256 _standardizedAmount) {
        ///TODO: invest() in strategy (should call separate contract)
        require(block.timestamp >= startTime);
        (,int price,,,) = AggregatorV3Interface(chainlinkPriceFeed).latestRoundData();
        require(price > 0);
        totalDeposits += amount;
        uint256 convertedPrice = uint256(price);
        uint256 standardizedPrice = standardizeBase9Chainlink(convertedPrice);
        uint256 computedPriceRisk = computePriceRisk(standardizedPrice, longShort);
        uint256 standardizedAmount = standardizeBase9(amount, suppliedAsset);
        uint256 alpha = (standardizedAmount * computedPriceRisk * (finalTime - block.timestamp)) / duration;

        tokenCount++;
        uint256 newTokenID = tokenCount;

        UserDeposit storage d = tokenToPosition[newTokenID];

        d.amount = amount;
        d.timeStamp = block.timestamp;
        d.assetPrice = standardizedPrice;
        d.longOrShort = longShort;
        d.alpha = alpha;

        if (longShort == true) {
            longs += alpha;
        } else if (longShort == false) {
            shorts += alpha;
        }

        //TODO: ask why issue when replacing with "amount" below (stack too deep error)
        IERC20(suppliedAsset).safeTransferFrom(_msgSender(), address(this), standardizedAmount * 10**9);
        IERC20(suppliedAsset).safeApprove(eulerStratContract, standardizedAmount * 10**9);
        IEulerStrat(eulerStratContract).deposit(suppliedAsset, standardizedAmount * 10**9);
        _safeMint(_msgSender(), newTokenID);

        return (computedPriceRisk, alpha, standardizedPrice, standardizedAmount);
    }


    function computePriceRisk(uint256 price, bool longOrShort) private view returns (uint256 rho) {
        if (longOrShort == true) {
            if (price > strikePrice) {
                return 10**9;
            } else if (price <= strikePrice) {
                rho = 10**9 + (((strikePrice - price) * 10**9) / deltaPrice);
                return rho;
            }
        }

        if (longOrShort == false) {
            if (strikePrice > price) {
                return 10**9;
            } else if (strikePrice <= price) {
                rho = 10**9 + (((price - strikePrice) * 10**9) / deltaPrice);
                return  rho;
            }
        }
    }

    function closePool() external onlyOwner {
        require(block.timestamp > finalTime);
        poolIsClosed = true;
        (,int price,,,) = AggregatorV3Interface(chainlinkPriceFeed).latestRoundData();
        require(price > 0);
        endPrice = uint256(price);
        uint256 returnedAmount = IEulerStrat(eulerStratContract).withdraw();
        if (returnedAmount <= totalDeposits) {
            totalReturnedFromStrat = returnedAmount;
        } else if (returnedAmount > totalDeposits) {
            totalRewards = returnedAmount - totalDeposits;
        }

    }

    function getReward(uint256 tokenID) external returns (uint256 amountOwedTokenID) {
        require(block.timestamp > finalTime && poolIsClosed == true);
        require(ownerOf(tokenID) == _msgSender(), "user is not Owner of token ID");

        if (totalReturnedFromStrat > 0) {
            amountOwedTokenID = (tokenToPosition[tokenID].amount * totalReturnedFromStrat) / totalDeposits;
            IERC20(suppliedAsset).safeTransfer(_msgSender(), amountOwedTokenID);
        } else {
            if (endPrice >= strikePrice && tokenToPosition[tokenID].longOrShort == true) {
                uint256 alpha = tokenToPosition[tokenID].alpha;
                amountOwedTokenID = (totalRewards * alpha) / longs;
            }

            if (endPrice < strikePrice && tokenToPosition[tokenID].longOrShort == false) {
                uint256 alpha = tokenToPosition[tokenID].alpha;
                amountOwedTokenID = (totalRewards * alpha) / shorts;
             }

            amountOwedTokenID += tokenToPosition[tokenID].amount;
            IERC20(suppliedAsset).safeTransfer(_msgSender(), amountOwedTokenID);


        }
    }

    function standardizeBase9Chainlink(uint256 amount) private view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        
        if (AggregatorV3Interface(chainlinkPriceFeed).decimals() < 9) {
            standardizedAmount *= 10 ** (9 - AggregatorV3Interface(chainlinkPriceFeed).decimals());
        } else if (AggregatorV3Interface(chainlinkPriceFeed).decimals() > 9) {
            standardizedAmount /= 10 ** (AggregatorV3Interface(chainlinkPriceFeed).decimals() - 9);
        }
    }

    function standardizeBase9(uint256 amount, address asset) private view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        
        if (IERC20Metadata(asset).decimals() < 9) {
            standardizedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals());
        } else if (IERC20Metadata(asset).decimals() > 9) {
            standardizedAmount /= 10 ** (IERC20Metadata(asset).decimals() - 9);
        }
    }

    function setTotalRewardsAndPrice(uint256 _amount, uint256 _endPrice) public {
        totalRewards += _amount;
        endPrice = _endPrice;
    }


}

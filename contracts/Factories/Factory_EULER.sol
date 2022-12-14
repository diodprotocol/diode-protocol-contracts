// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "../Diode.sol";
import "../Strategies/Mainnet/EulerStrat.sol";

    // ============================ Interfaces ========================

    interface IDiodePool {
        function setStrategy(address) external;
    }


    // ============================ Contract ==========================


/// @title Diode protocol Pool Factory
/// @author Diode Protocol core team 

contract Factory_EULER {


    // ============================ Events ==========================


    event NewDiodePool(       
        uint256 _strikePrice, 
        address _asset,
        uint256 _duration,
        uint256 _startTime,
        uint256 _deltaPrice,
        address _chainlinkPriceFeed,
        uint256 _fees,
        uint256[2] _capLongShort,
        string  _name,
        string  _symbol
    );

    event NewEulerStrat(
        address _underlyingToken,
        address _pool
    );


    // ============================ State Variables ==========================

    /// @notice List of all Diode Pools contract addresses
    address[] public diodePoolsList;

    /// @notice List of Euler Strategy addresses
    address[] public eulerStratList;


    // ============================ Constructor ==========================

    constructor() {
    }

    // ============================ Functions ==========================

    /// @notice Deploys a Diode Pool and links an Euler strategy to the pool.
    function deployDiodePool(
        uint256 _strikePrice, 
        address _asset,
        uint256 _duration,
        uint256 _startTime,
        uint256 _deltaPrice,
        address _chainlinkPriceFeed,
        uint256 _fees,
        uint256[2] memory _capLongShort,
        string memory _name,
        string memory _symbol
    ) external returns (address deployedPool, address deployedEulerStrat) {
  
        deployedPool = address(new Diode(
            _strikePrice,
            _asset,
            _duration,
            _startTime,
            _deltaPrice,
            _chainlinkPriceFeed,
            _fees,
            _capLongShort,
            _name,
            _symbol
            ));

        diodePoolsList.push(deployedPool);
        emit NewDiodePool(_strikePrice, _asset, _duration, _startTime, _deltaPrice, _chainlinkPriceFeed, _fees, _capLongShort, _name, _symbol);

        deployedEulerStrat = address(new EulerStrat(
            _asset,
            deployedPool
        ));

        eulerStratList.push(deployedEulerStrat);
        emit NewEulerStrat(_asset, deployedPool);

        IDiodePool(deployedPool).setStrategy(deployedEulerStrat);

    }

    // ============================ View Functions ==========================


    /// @notice Returns all the Diode Pools
    /// @dev Helper for UIs
    function getAllDiodePools() external view returns (address[] memory) {
        return diodePoolsList;
    }


    /// @notice Returns all the Diode Pools
    /// @dev Helper for UIs
    function getAllEulerStrats() external view returns (address[] memory) {
        return eulerStratList;
    }

}
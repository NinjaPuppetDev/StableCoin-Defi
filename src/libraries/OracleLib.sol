// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

uint256 constant TIMEOUT = 3 hours;

/*
 * @title OracleLib
 * @author David
 * @notice This library is used to check the chainlink Oracle for stale data.
 * We want DSCEngine to freeze if prices become stale.
 */

library OracleLib {
    error OracleLib__StalePrice();

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}

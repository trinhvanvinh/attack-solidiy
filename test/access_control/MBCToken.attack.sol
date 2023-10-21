// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {TestHarness} from "../TestHarness.sol";
import {TokenBalanceTracker} from "../modules/TokenBalanceTracker.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IUniswapV2Pair} from "../utils/IUniswapV2Pair.sol";

interface IDppOracle {
    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address _assetTo,
        bytes memory data
    ) external;
}

interface ILiqToken is IERC20 {
    function swapAndLiquifyStepv1() external;
}

contract Exploit_MBCToken is TestHarness, TokenBalanceTracker {
    IDppOracle internal dppOracle =
        IDppOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);

    IERC20 internal usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    ILiqToken internal mbc =
        ILiqToken(0x4E87880A72f6896E7e0a635A5838fFc89b13bd17);
    ILiqToken internal zzsh =
        ILiqToken(0xeE04a3f9795897fd74b7F04Bb299Ba25521606e6);

    ILiqToken[] internal liqTokens = [mbc, zzsh];

    IUniswapV2Pair internal pairUsdtMbc =
        IUniswapV2Pair(0x5b1Bf836fba1836Ca7ffCE26f155c75dBFa4aDF1);
    IUniswapV2Pair internal pairUsdtZzsh =
        IUniswapV2Pair(0x33CCA0E0CFf617a2aef1397113E779E42a06a74A);

    IUniswapV2Pair[] internal pairs = [pairUsdtMbc, pairUsdtZzsh];

    function setUp() external {
        cheat.createSelectFork("bsc", 23474460);
        cheat.deal(address(this), 0);

        addTokenToTracker(address(usdt));
        addTokenToTracker(address(mbc));
        addTokenToTracker(address(zzsh));

        updateBalanceTracker(address(this));
        updateBalanceTracker(address(pairUsdtZzsh));
        updateBalanceTracker(address(pairUsdtMbc));
        updateBalanceTracker(address(mbc));
        updateBalanceTracker(address(zzsh));
    }

    // function test_attack() external {
    //     console.log("--- Resquest flashLoan --- ");
    //     logBalancesWithLabel("Attacker contract", address(this));
    //     uint256 balanceUsdtBefore = usdt.balanceOf(address(this));
    //     uint256 balanceMbBefore = mbc.balanceOf(address(this));
    //     uint256 balanceZZSHBefore = zzsh.balanceOf(address(this));
    //     console.log("ssss");
    //     dppOracle.flashLoan(
    //         0,
    //         usdt.balanceOf(address(dppOracle)),
    //         address(this),
    //         hex'30'
    //     );
    //     console.log("aaa");
    // }

    function test_DPPFlashLoanCall(
        address sender,
        uint256 amount1,
        uint256 amount2,
        bytes memory
    ) external {
        console.log("111");
        require(msg.sender == address(dppOracle), "Only oracle");
    }
}

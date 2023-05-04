// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "../../pool-utils/contracts/BaseMinimalSwapInfoPool.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/ScalingHelpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";

import "./WeightedMath.sol";

abstract contract BaseWeightedPool is BaseMinimalSwapInfoPool {
    using FixedPoint for uint256;

    // A minimum normalized weight imposes a maximum weight ratio. We need this due to limitations in the
    // implementation of the power function, as these ratios are often exponents.
    uint256 internal constant _MIN_WEIGHT = 0.01e18;
    // Having a minimum normalized weight imposes a limit on the maximum number of tokens;
    // i.e., the largest possible pool is one where all tokens have exactly the minimum weight.
    uint256 internal constant _MAX_WEIGHTED_TOKENS = 100;

    // Swap limits: amounts swapped may not be larger than this percentage of total balance.
    uint256 internal constant _MAX_IN_RATIO = 0.3e18;
    uint256 internal constant _MAX_OUT_RATIO = 0.3e18;

    constructor(
        IVault vault,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        address[] memory assetManagers,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner,
        bool mutableTokens
    )
        BasePool(
            vault,
            // Given BaseMinimalSwapInfoPool supports both of these specializations, and this Pool never registers
            // or deregisters any tokens after construction, picking Two Token when the Pool only has two tokens is free
            // gas savings.
            // If the pool is expected to be able register new tokens in future, we must choose MINIMAL_SWAP_INFO
            // as clearly the TWO_TOKEN specification doesn't support adding extra tokens in future.
            tokens.length == 2 && !mutableTokens
                ? IVault.PoolSpecialization.TWO_TOKEN
                : IVault.PoolSpecialization.MINIMAL_SWAP_INFO,
            name,
            symbol,
            tokens,
            assetManagers,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner
        )
    {}

    function _scalingFactor(IERC20 token) internal view virtual override returns (uint256);

    function _scalingFactors() internal view virtual override returns (uint256[] memory);

    function _getTotalTokens() internal view virtual override returns (uint256);

    function _getMaxTokens() internal pure virtual override returns (uint256);

    // Virtual functions

    /**
     * @dev Returns the normalized weight of `token`. Weights are fixed point numbers that sum to FixedPoint.ONE.
     */
    function _getNormalizedWeight(IERC20 token) internal view virtual returns (uint256);

    /**
     * @dev Returns all normalized weights, in the same order as the Pool's tokens.
     */
    function _getNormalizedWeights() internal view virtual returns (uint256[] memory);

    function getNormalizedWeights() external view returns (uint256[] memory) {
        return _getNormalizedWeights();
    }

    /**
     * @dev Same as `_upscale`, but for an entire array. This function does not return anything, but instead *mutates*
     * the `amounts` array.
     */
    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure {
        uint256 length = amounts.length;
        InputHelpers.ensureInputLengthMatch(length, scalingFactors.length);

        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }

    // TODO: This cause zksolc to hang for some reason
    //
    // *** issue is _calculateInvariant() ***
    // If code inside _calculateInvariant() is commented out build is fine, hangs otherwise
    //
    /**
     * @dev Returns the current value of the invariant.
     */
    function getInvariant() public view returns (uint256) {
        (, uint256[] memory balances, ) = getVault().getPoolTokens(getPoolId());

        // // Since the Pool hooks always work with upscaled balances, we manually
        // // upscale here for consistency
        _upscaleArray(balances, _scalingFactors());

        uint256[] memory normalizedWeights = _getNormalizedWeights();

        // TODO: Both cases here only build when the code is commented out
        // So library import or internal function is not the issue

        // Try "lite" math version. The calcs in FixedPoint might be the issue?
        // return WeightedMath._calculateInvariant(normalizedWeights, balances);
        return _calculateInvariant(normalizedWeights, balances);
    }

    // About swap fees on joins and exits:
    // Any join or exit that is not perfectly balanced (e.g. all single token joins or exits) is mathematically
    // equivalent to a perfectly balanced join or exit followed by a series of swaps. Since these swaps would charge
    // swap fees, it follows that (some) joins and exits should as well.
    // On these operations, we split the token amounts in 'taxable' and 'non-taxable' portions, where the 'taxable' part
    // is the one to which swap fees are applied.

    // Invariant is used to collect protocol swap fees by comparing its value between two times.
    // So we can round always to the same direction. It is also used to initiate the BPT amount
    // and, because there is a minimum BPT, we round down the invariant.
    function _calculateInvariant(
        uint256[] memory normalizedWeights,
        uint256[] memory balances
    ) internal pure returns (uint256 invariant) {
        /**********************************************************************************************
        // invariant               _____                                                             //
        // wi = weight index i      | |      wi                                                      //
        // bi = balance index i     | |  bi ^   = i                                                  //
        // i = invariant                                                                             //
        **********************************************************************************************/
        // uint256 invariant = FixedPoint.ONE;
        // for (uint256 i = 0; i < normalizedWeights.length; i++) {
        //     invariant = invariant.mulDown(balances[i].powDown(normalizedWeights[i]));
        // }
        // _require(invariant > 0, Errors.ZERO_INVARIANT);
        // return invariant;
    }

    // Base Pool handlers

    // Swap

    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal virtual override returns (uint256) {
        // return
        //     WeightedMath._calcOutGivenIn(
        //         currentBalanceTokenIn,
        //         _getNormalizedWeight(swapRequest.tokenIn),
        //         currentBalanceTokenOut,
        //         _getNormalizedWeight(swapRequest.tokenOut),
        //         swapRequest.amount
        //     );

        return 0;
    }

    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal virtual override returns (uint256) {
        // return
        //     WeightedMath._calcInGivenOut(
        //         currentBalanceTokenIn,
        //         _getNormalizedWeight(swapRequest.tokenIn),
        //         currentBalanceTokenOut,
        //         _getNormalizedWeight(swapRequest.tokenOut),
        //         swapRequest.amount
        //     );

        return 0;
    }

    // Initialize

    function _onInitializePool(
        bytes32,
        address,
        address,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override returns (uint256, uint256[] memory) {
        // WeightedPoolUserData.JoinKind kind = userData.joinKind();
        // _require(kind == WeightedPoolUserData.JoinKind.INIT, Errors.UNINITIALIZED);

        // uint256[] memory amountsIn = userData.initialAmountsIn();
        // InputHelpers.ensureInputLengthMatch(amountsIn.length, scalingFactors.length);
        // _upscaleArray(amountsIn, scalingFactors);

        // uint256[] memory normalizedWeights = _getNormalizedWeights();
        // uint256 invariantAfterJoin = WeightedMath._calculateInvariant(normalizedWeights, amountsIn);

        // // Set the initial BPT to the value of the invariant times the number of tokens. This makes BPT supply more
        // // consistent in Pools with similar compositions but different number of tokens.
        // uint256 bptAmountOut = Math.mul(invariantAfterJoin, amountsIn.length);

        // // Initialization is still a join, so we need to do post-join work. Since we are not paying protocol fees,
        // // and all we need to do is update the invariant,
        // call `_updatePostJoinExit` here instead of `_afterJoinExit`.
        // _updatePostJoinExit(invariantAfterJoin);

        // return (bptAmountOut, amountsIn);

        return (0, new uint256[](0));
    }

    // Join

    function _onJoinPool(
        bytes32,
        address sender,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override returns (uint256, uint256[] memory) {
        // uint256[] memory normalizedWeights = _getNormalizedWeights();

        // (uint256 preJoinExitSupply, uint256 preJoinExitInvariant) = _beforeJoinExit(balances, normalizedWeights);

        // (uint256 bptAmountOut, uint256[] memory amountsIn) = _doJoin(
        //     sender,
        //     balances,
        //     normalizedWeights,
        //     scalingFactors,
        //     preJoinExitSupply,
        //     userData
        // );

        // _afterJoinExit(
        //     preJoinExitInvariant,
        //     balances,
        //     amountsIn,
        //     normalizedWeights,
        //     preJoinExitSupply,
        //     preJoinExitSupply.add(bptAmountOut)
        // );

        // return (bptAmountOut, amountsIn);

        return (0, new uint256[](0));
    }

    // Exit

    function _onExitPool(
        bytes32,
        address sender,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override returns (uint256, uint256[] memory) {
        // uint256[] memory normalizedWeights = _getNormalizedWeights();

        // (uint256 preJoinExitSupply, uint256 preJoinExitInvariant) = _beforeJoinExit(balances, normalizedWeights);

        // (uint256 bptAmountIn, uint256[] memory amountsOut) = _doExit(
        //     sender,
        //     balances,
        //     normalizedWeights,
        //     scalingFactors,
        //     preJoinExitSupply,
        //     userData
        // );

        // _afterJoinExit(
        //     preJoinExitInvariant,
        //     balances,
        //     amountsOut,
        //     normalizedWeights,
        //     preJoinExitSupply,
        //     preJoinExitSupply.sub(bptAmountIn)
        // );

        // return (bptAmountIn, amountsOut);
        return (0, new uint256[](0));
    }

    function _doRecoveryModeExit(
        uint256[] memory balances,
        uint256 totalSupply,
        bytes memory userData
    ) internal pure override returns (uint256 bptAmountIn, uint256[] memory amountsOut) {
        // bptAmountIn = userData.recoveryModeExit();
        // amountsOut = BasePoolMath.computeProportionalAmountsOut(balances, totalSupply, bptAmountIn);
    }

    // MAFS

    // Computes how many tokens can be taken out of a pool if `amountIn` are sent, given the
    // current balances and weights.
    function _calcOutGivenIn(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountIn
    ) internal pure returns (uint256) {
        /**********************************************************************************************
        // outGivenIn                                                                                //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /      /            bI             \    (wI / wO) \           //
        // aI = amountIn    aO = bO * |  1 - | --------------------------  | ^            |          //
        // wI = weightIn               \      \       ( bI + aI )         /              /           //
        // wO = weightOut                                                                            //
        **********************************************************************************************/

        // Amount out, so we round down overall.

        // The multiplication rounds down, and the subtrahend (power) rounds up (so the base rounds up too).
        // Because bI / (bI + aI) <= 1, the exponent rounds down.

        // Cannot exceed maximum in ratio
        _require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);

        uint256 denominator = balanceIn.add(amountIn);
        uint256 base = balanceIn.divUp(denominator);
        uint256 exponent = weightIn.divDown(weightOut);
        uint256 power = base.powUp(exponent);

        return balanceOut.mulDown(power.complement());
    }

    // Computes how many tokens must be sent to a pool in order to take `amountOut`, given the
    // current balances and weights.
    function _calcInGivenOut(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountOut
    ) internal pure returns (uint256) {
        /**********************************************************************************************
        // inGivenOut                                                                                //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /  /            bO             \    (wO / wI)      \          //
        // aI = amountIn    aI = bI * |  | --------------------------  | ^            - 1  |         //
        // wI = weightIn               \  \       ( bO - aO )         /                   /          //
        // wO = weightOut                                                                            //
        **********************************************************************************************/

        // Amount in, so we round up overall.

        // The multiplication rounds up, and the power rounds up (so the base rounds up too).
        // Because b0 / (b0 - a0) >= 1, the exponent rounds up.

        // Cannot exceed maximum out ratio
        _require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);

        uint256 base = balanceOut.divUp(balanceOut.sub(amountOut));
        uint256 exponent = weightOut.divUp(weightIn);
        uint256 power = base.powUp(exponent);

        // Because the base is larger than one (and the power rounds up), the power should always be larger than one, so
        // the following subtraction should never revert.
        uint256 ratio = power.sub(FixedPoint.ONE);

        return balanceIn.mulUp(ratio);
    }
}

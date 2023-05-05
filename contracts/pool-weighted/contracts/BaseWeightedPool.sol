// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "../../pool-utils/contracts/BaseMinimalSwapInfoPool.sol";
import "../../solidity-utils/contracts/helpers/ScalingHelpers.sol";
import "../../solidity-utils/contracts/math/FixedPointLite.sol";
import "../../interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import "./WeightedMath.sol";

abstract contract BaseWeightedPool is BaseMinimalSwapInfoPool {
    using FixedPointLite for uint256;
    using WeightedPoolUserData for bytes;

    constructor(
        IVault vault,
        string memory _name,
        string memory _symbol,
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
            _name,
            _symbol,
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
     * @dev Returns the current value of the invariant.
     */
    function getInvariant() public view returns (uint256) {
        (, uint256[] memory balances, ) = getVault().getPoolTokens(getPoolId());

        // // Since the Pool hooks always work with upscaled balances, we manually
        // // upscale here for consistency
        _upscaleArray(balances, _scalingFactors());

        uint256[] memory normalizedWeights = _getNormalizedWeights();

        return WeightedMath._calculateInvariant(normalizedWeights, balances);
    }

    // Base Pool handlers

    // Swap

    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal virtual override returns (uint256) {
        return
            WeightedMath._calcOutGivenIn(
                currentBalanceTokenIn,
                _getNormalizedWeight(swapRequest.tokenIn),
                currentBalanceTokenOut,
                _getNormalizedWeight(swapRequest.tokenOut),
                swapRequest.amount
            );
    }

    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal virtual override returns (uint256) {
        return
            WeightedMath._calcInGivenOut(
                currentBalanceTokenIn,
                _getNormalizedWeight(swapRequest.tokenIn),
                currentBalanceTokenOut,
                _getNormalizedWeight(swapRequest.tokenOut),
                swapRequest.amount
            );
    }

    /**
     * @dev Called after any regular join or exit operation. Empty by default, but derived contracts
     * may choose to add custom behavior at these steps. This often has to do with protocol fee processing.
     *
     * If performing a join operation, balanceDeltas are the amounts in: otherwise they are the amounts out.
     *
     * This function is free to mutate the `preBalances` array.
     */
    function _afterJoinExit(
        uint256 preJoinExitInvariant,
        uint256[] memory preBalances,
        uint256[] memory balanceDeltas,
        uint256[] memory normalizedWeights,
        uint256 preJoinExitSupply,
        uint256 postJoinExitSupply
    ) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    // Derived contracts may call this to update state after a join or exit.
    function _updatePostJoinExit(uint256 postJoinExitInvariant) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    // Initialize

    function _onInitializePool(
        bytes32,
        address,
        address,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override returns (uint256, uint256[] memory) {
        WeightedPoolUserData.JoinKind kind = userData.joinKind();
        _require(kind == WeightedPoolUserData.JoinKind.INIT, Errors.UNINITIALIZED);

        uint256[] memory amountsIn = userData.initialAmountsIn();
        InputHelpers.ensureInputLengthMatch(amountsIn.length, scalingFactors.length);
        _upscaleArray(amountsIn, scalingFactors);

        uint256[] memory normalizedWeights = _getNormalizedWeights();
        uint256 invariantAfterJoin = WeightedMath._calculateInvariant(normalizedWeights, amountsIn);

        // Set the initial BPT to the value of the invariant times the number of tokens. This makes BPT supply more
        // consistent in Pools with similar compositions but different number of tokens.
        uint256 bptAmountOut = Math.mul(invariantAfterJoin, amountsIn.length);

        // Initialization is still a join, so we need to do post-join work. Since we are not paying protocol fees,
        // and all we need to do is update the invariant,
        // call `_updatePostJoinExit` here instead of `_afterJoinExit`.
        _updatePostJoinExit(invariantAfterJoin);

        return (bptAmountOut, amountsIn);
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
}

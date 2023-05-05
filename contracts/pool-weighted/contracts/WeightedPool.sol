// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";

import "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "@balancer-labs/v2-interfaces/contracts/standalone-utils/IProtocolFeePercentagesProvider.sol";

import "./BaseWeightedPool.sol";
import "./WeightedPoolProtocolFees.sol";

import "./WeightedMath.sol";

import "../../solidity-utils/contracts/math/FixedPointLite.sol";

contract WeightedPool is BaseWeightedPool, WeightedPoolProtocolFees {
    using FixedPointLite for uint256;

    /// @dev Reduced to 7 from 8 for zksync compilation error
    uint256 private constant _MAX_TOKENS = 7;

    uint256 private immutable _totalTokens;

    IERC20 internal immutable _token0;
    IERC20 internal immutable _token1;
    IERC20 internal immutable _token2;
    IERC20 internal immutable _token3;
    IERC20 internal immutable _token4;
    IERC20 internal immutable _token5;
    IERC20 internal immutable _token6;
    // IERC20 internal immutable _token7;

    // All token balances are normalized to behave as if the token had 18 decimals. We assume a token's decimals will
    // not change throughout its lifetime, and store the corresponding scaling factor for each at construction time.
    // These factors are always greater than or equal to one: tokens with more than 18 decimals are not supported.

    uint256 internal immutable _scalingFactor0;
    uint256 internal immutable _scalingFactor1;
    uint256 internal immutable _scalingFactor2;
    uint256 internal immutable _scalingFactor3;
    uint256 internal immutable _scalingFactor4;
    uint256 internal immutable _scalingFactor5;
    uint256 internal immutable _scalingFactor6;
    // uint256 internal immutable _scalingFactor7;

    uint256 internal immutable _normalizedWeight0;
    uint256 internal immutable _normalizedWeight1;
    uint256 internal immutable _normalizedWeight2;
    uint256 internal immutable _normalizedWeight3;
    uint256 internal immutable _normalizedWeight4;
    uint256 internal immutable _normalizedWeight5;
    uint256 internal immutable _normalizedWeight6;
    // uint256 internal immutable _normalizedWeight7;

    struct NewPoolParams {
        string name;
        string symbol;
        IERC20[] tokens;
        uint256[] normalizedWeights;
        IRateProvider[] rateProviders;
        address[] assetManagers;
        uint256 swapFeePercentage;
    }

    constructor(
        NewPoolParams memory params,
        IVault vault,
        IProtocolFeePercentagesProvider protocolFeeProvider,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    )
        BaseWeightedPool(
            vault,
            params.name,
            params.symbol,
            params.tokens,
            params.assetManagers,
            params.swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner,
            false
        )
        ProtocolFeeCache(
            protocolFeeProvider,
            ProviderFeeIDs({ swap: ProtocolFeeType.SWAP, yield: ProtocolFeeType.YIELD, aum: ProtocolFeeType.AUM })
        )
        WeightedPoolProtocolFees(params.tokens.length, params.rateProviders)
    {
        uint256 numTokens = params.tokens.length;
        InputHelpers.ensureInputLengthMatch(numTokens, params.normalizedWeights.length);

        _totalTokens = numTokens;

        // Ensure each normalized weight is above the minimum
        uint256 normalizedSum = 0;
        for (uint8 i = 0; i < numTokens; i++) {
            uint256 normalizedWeight = params.normalizedWeights[i];

            _require(normalizedWeight >= WeightedMath._MIN_WEIGHT, Errors.MIN_WEIGHT);
            normalizedSum = normalizedSum.add(normalizedWeight);
        }
        // Ensure that the normalized weights sum to ONE
        _require(normalizedSum == FixedPoint.ONE, Errors.NORMALIZED_WEIGHT_INVARIANT);

        // Immutable variables cannot be initialized inside an if statement, so we must do conditional assignments
        _token0 = params.tokens[0];
        _token1 = params.tokens[1];
        _token2 = numTokens > 2 ? params.tokens[2] : IERC20(0);
        _token3 = numTokens > 3 ? params.tokens[3] : IERC20(0);
        _token4 = numTokens > 4 ? params.tokens[4] : IERC20(0);
        _token5 = numTokens > 5 ? params.tokens[5] : IERC20(0);
        _token6 = numTokens > 6 ? params.tokens[6] : IERC20(0);
        // _token7 = numTokens > 7 ? params.tokens[7] : IERC20(0);

        _scalingFactor0 = _computeScalingFactor(params.tokens[0]);
        _scalingFactor1 = _computeScalingFactor(params.tokens[1]);
        _scalingFactor2 = numTokens > 2 ? _computeScalingFactor(params.tokens[2]) : 0;
        _scalingFactor3 = numTokens > 3 ? _computeScalingFactor(params.tokens[3]) : 0;
        _scalingFactor4 = numTokens > 4 ? _computeScalingFactor(params.tokens[4]) : 0;
        _scalingFactor5 = numTokens > 5 ? _computeScalingFactor(params.tokens[5]) : 0;
        _scalingFactor6 = numTokens > 6 ? _computeScalingFactor(params.tokens[6]) : 0;
        // _scalingFactor7 = numTokens > 7 ? _computeScalingFactor(params.tokens[7]) : 0;

        _normalizedWeight0 = params.normalizedWeights[0];
        _normalizedWeight1 = params.normalizedWeights[1];
        _normalizedWeight2 = numTokens > 2 ? params.normalizedWeights[2] : 0;
        _normalizedWeight3 = numTokens > 3 ? params.normalizedWeights[3] : 0;
        _normalizedWeight4 = numTokens > 4 ? params.normalizedWeights[4] : 0;
        _normalizedWeight5 = numTokens > 5 ? params.normalizedWeights[5] : 0;
        _normalizedWeight6 = numTokens > 6 ? params.normalizedWeights[6] : 0;
        // _normalizedWeight7 = numTokens > 7 ? params.normalizedWeights[7] : 0;
    }

    function _getNormalizedWeight(IERC20 token) internal view virtual override returns (uint256) {
        // prettier-ignore
        if (token == _token0) { return _normalizedWeight0; }
        else if (token == _token1) { return _normalizedWeight1; }
        else if (token == _token2) { return _normalizedWeight2; }
        else if (token == _token3) { return _normalizedWeight3; }
        else if (token == _token4) { return _normalizedWeight4; }
        else if (token == _token5) { return _normalizedWeight5; }
        else if (token == _token6) { return _normalizedWeight6; }
        // else if (token == _token7) { return _normalizedWeight7; }
        else {
            _revert(Errors.INVALID_TOKEN);
        }
    }

    function _getNormalizedWeights() internal view virtual override returns (uint256[] memory) {
        uint256 totalTokens = _getTotalTokens();
        uint256[] memory normalizedWeights = new uint256[](totalTokens);

        // prettier-ignore
        {
            normalizedWeights[0] = _normalizedWeight0;
            normalizedWeights[1] = _normalizedWeight1;
            if (totalTokens > 2) { normalizedWeights[2] = _normalizedWeight2; } else { return normalizedWeights; }
            if (totalTokens > 3) { normalizedWeights[3] = _normalizedWeight3; } else { return normalizedWeights; }
            if (totalTokens > 4) { normalizedWeights[4] = _normalizedWeight4; } else { return normalizedWeights; }
            if (totalTokens > 5) { normalizedWeights[5] = _normalizedWeight5; } else { return normalizedWeights; }
            if (totalTokens > 6) { normalizedWeights[6] = _normalizedWeight6; } else { return normalizedWeights; }
          // if (totalTokens > 7) { normalizedWeights[7] = _normalizedWeight7; } else { return normalizedWeights; }
        }

        return normalizedWeights;
    }

    function _getMaxTokens() internal pure virtual override returns (uint256) {
        return _MAX_TOKENS;
    }

    function _getTotalTokens() internal view virtual override returns (uint256) {
        return _totalTokens;
    }

    /**
     * @dev Returns the scaling factor for one of the Pool's tokens. Reverts if `token` is not a token registered by the
     * Pool.
     */
    function _scalingFactor(IERC20 token) internal view virtual override returns (uint256) {
        // prettier-ignore
        if (token == _token0) { return _getScalingFactor0(); }
        else if (token == _token1) { return _getScalingFactor1(); }
        else if (token == _token2) { return _getScalingFactor2(); }
        else if (token == _token3) { return _getScalingFactor3(); }
        else if (token == _token4) { return _getScalingFactor4(); }
        else if (token == _token5) { return _getScalingFactor5(); }
        else if (token == _token6) { return _getScalingFactor6(); }
       // else if (token == _token7) { return _getScalingFactor7(); }
        else {
            _revert(Errors.INVALID_TOKEN);
        }
    }

    function _scalingFactors() internal view virtual override returns (uint256[] memory) {
        uint256 totalTokens = _getTotalTokens();
        uint256[] memory scalingFactors = new uint256[](totalTokens);

        // prettier-ignore
        {
            scalingFactors[0] = _getScalingFactor0();
            scalingFactors[1] = _getScalingFactor1();
            if (totalTokens > 2) { scalingFactors[2] = _getScalingFactor2(); } else { return scalingFactors; }
            if (totalTokens > 3) { scalingFactors[3] = _getScalingFactor3(); } else { return scalingFactors; }
            if (totalTokens > 4) { scalingFactors[4] = _getScalingFactor4(); } else { return scalingFactors; }
            if (totalTokens > 5) { scalingFactors[5] = _getScalingFactor5(); } else { return scalingFactors; }
            if (totalTokens > 6) { scalingFactors[6] = _getScalingFactor6(); } else { return scalingFactors; }
            // if (totalTokens > 7) { scalingFactors[7] = _getScalingFactor7(); } else { return scalingFactors; }
        }

        return scalingFactors;
    }

    // Initialize

    function _onInitializePool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override returns (uint256, uint256[] memory) {
        // Initialize `_athRateProduct` if the Pool will pay protocol fees on yield.
        // Not initializing this here properly will cause all joins/exits to revert.
        if (!_isExemptFromYieldProtocolFees()) _updateATHRateProduct(_getRateProduct(_getNormalizedWeights()));

        return super._onInitializePool(poolId, sender, recipient, scalingFactors, userData);
    }

    // WeightedPoolProtocolFees functions

    function _beforeJoinExit(
        uint256[] memory preBalances,
        uint256[] memory normalizedWeights
    ) internal virtual override returns (uint256, uint256) {
        uint256 supplyBeforeFeeCollection = totalSupply();
        uint256 invariant = WeightedMath._calculateInvariant(normalizedWeights, preBalances);
        (uint256 protocolFeesToBeMinted, uint256 athRateProduct) = _getPreJoinExitProtocolFees(
            invariant,
            normalizedWeights,
            supplyBeforeFeeCollection
        );

        // We then update the recorded value of `athRateProduct` to ensure we only collect fees on yield once.
        // A zero value for `athRateProduct` represents that it is unchanged so we can skip updating it.
        if (athRateProduct > 0) {
            _updateATHRateProduct(athRateProduct);
        }

        _payProtocolFees(protocolFeesToBeMinted);

        return (supplyBeforeFeeCollection.add(protocolFeesToBeMinted), invariant);
    }

    function _updatePostJoinExit(
        uint256 postJoinExitInvariant
    ) internal virtual override(BaseWeightedPool, WeightedPoolProtocolFees) {
        WeightedPoolProtocolFees._updatePostJoinExit(postJoinExitInvariant);
    }

    function _getScalingFactor0() internal view returns (uint256) {
        return _scalingFactor0;
    }

    function _getScalingFactor1() internal view returns (uint256) {
        return _scalingFactor1;
    }

    function _getScalingFactor2() internal view returns (uint256) {
        return _scalingFactor2;
    }

    function _getScalingFactor3() internal view returns (uint256) {
        return _scalingFactor3;
    }

    function _getScalingFactor4() internal view returns (uint256) {
        return _scalingFactor4;
    }

    function _getScalingFactor5() internal view returns (uint256) {
        return _scalingFactor5;
    }

    function _getScalingFactor6() internal view returns (uint256) {
        return _scalingFactor6;
    }

    // function _getScalingFactor7() internal view returns (uint256) {
    //     return _scalingFactor7;
    // }

    function _isOwnerOnlyAction(
        bytes32 actionId
    ) internal view virtual override(BasePool, WeightedPoolProtocolFees) returns (bool) {
        return super._isOwnerOnlyAction(actionId);
    }
}

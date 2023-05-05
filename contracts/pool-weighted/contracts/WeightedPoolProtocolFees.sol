// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "@balancer-labs/v2-pool-utils/contracts/external-fees/ProtocolFeeCache.sol";
import "../../pool-utils/contracts/external-fees/InvariantGrowthProtocolSwapFees.sol";
import "./BaseWeightedPool.sol";

abstract contract WeightedPoolProtocolFees is BaseWeightedPool, ProtocolFeeCache, IRateProvider {
    using FixedPointLite for uint256;
    using WordCodec for bytes32;

    // Rate providers are used only for computing yield fees; they do not inform swap/join/exit.
    IRateProvider internal immutable _rateProvider0;
    IRateProvider internal immutable _rateProvider1;
    IRateProvider internal immutable _rateProvider2;
    IRateProvider internal immutable _rateProvider3;
    IRateProvider internal immutable _rateProvider4;
    IRateProvider internal immutable _rateProvider5;
    IRateProvider internal immutable _rateProvider6;
    IRateProvider internal immutable _rateProvider7;

    bool internal immutable _exemptFromYieldFees;

    // All-time high value of the weighted product of the pool's token rates. Comparing such weighted products across
    // time provides a measure of the pool's growth resulting from rate changes. The pool also grows due to swap fees,
    // but that growth is captured in the invariant; rate growth is not.
    uint256 private _athRateProduct;

    // This Pool pays protocol fees by measuring the growth of the invariant between joins and exits. Since weights are
    // immutable, the invariant only changes due to accumulated swap fees, which saves gas by freeing the Pool
    // from performing any computation or accounting associated with protocol fees during swaps.
    // This mechanism requires keeping track of the invariant after the last join or exit.
    //
    // The maximum value of the invariant is the maximum allowable balance in the Vault (2**112) multiplied by the
    // largest possible scaling factor (10**18 for a zero decimals token). The largest invariant is then
    // 2**112 * 10**18 ~= 2**172, which means that to save gas we can place this in BasePool's `_miscData`.
    uint256 private constant _LAST_POST_JOINEXIT_INVARIANT_OFFSET = 0;
    uint256 private constant _LAST_POST_JOINEXIT_INVARIANT_BIT_LENGTH = 192;

    constructor(uint256 numTokens, IRateProvider[] memory rateProviders) {
        _require(numTokens <= 8, Errors.MAX_TOKENS);
        InputHelpers.ensureInputLengthMatch(numTokens, rateProviders.length);

        _exemptFromYieldFees = _getYieldFeeExemption(rateProviders);

        _rateProvider0 = rateProviders[0];
        _rateProvider1 = rateProviders[1];
        _rateProvider2 = numTokens > 2 ? rateProviders[2] : IRateProvider(0);
        _rateProvider3 = numTokens > 3 ? rateProviders[3] : IRateProvider(0);
        _rateProvider4 = numTokens > 4 ? rateProviders[4] : IRateProvider(0);
        _rateProvider5 = numTokens > 5 ? rateProviders[5] : IRateProvider(0);
        _rateProvider6 = numTokens > 6 ? rateProviders[6] : IRateProvider(0);
        _rateProvider7 = numTokens > 7 ? rateProviders[7] : IRateProvider(0);
    }

    function _getYieldFeeExemption(IRateProvider[] memory rateProviders) internal pure returns (bool) {
        // If we know that no rate providers are set then we can skip yield fees logic.
        // If any tokens have rate providers, then set `_exemptFromYieldFees` to false, otherwise leave it true.
        for (uint256 i = 0; i < rateProviders.length; i++) {
            if (rateProviders[i] != IRateProvider(0)) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Returns whether the pool is exempt from protocol fees on yield.
     */
    function _isExemptFromYieldProtocolFees() internal view returns (bool) {
        return _exemptFromYieldFees;
    }

    /**
     * @notice Returns the value of the invariant after the last join or exit operation.
     */
    function getLastPostJoinExitInvariant() public view returns (uint256) {
        return
            _getMiscData().decodeUint(_LAST_POST_JOINEXIT_INVARIANT_OFFSET, _LAST_POST_JOINEXIT_INVARIANT_BIT_LENGTH);
    }

    /**
     * @notice Returns the all time high value for the weighted product of the Pool's tokens' rates.
     * @dev Yield protocol fees are only charged when this value is exceeded.
     */
    function getATHRateProduct() public view returns (uint256) {
        return _athRateProduct;
    }

    function _isOwnerOnlyAction(
        bytes32 actionId
    ) internal view virtual override(BasePool, BasePoolAuthorization) returns (bool) {
        return super._isOwnerOnlyAction(actionId);
    }
}

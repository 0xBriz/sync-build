// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "@balancer-labs/v2-pool-utils/contracts/external-fees/ProtocolFeeCache.sol";
import "../../pool-utils/contracts/external-fees/InvariantGrowthProtocolSwapFees.sol";
import "./BaseWeightedPool.sol";

abstract contract WeightedPoolProtocolFees is BaseWeightedPool, ProtocolFeeCache, IRateProvider {
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

    function _isOwnerOnlyAction(
        bytes32 actionId
    ) internal view virtual override(BasePool, BasePoolAuthorization) returns (bool) {
        return super._isOwnerOnlyAction(actionId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Gaussian} from "lib/solidity-cdf/src/Gaussian.sol";
import {FixedPointMathLib} from "lib/solmate/src/utils/FixedPointMathLib.sol";

/// @title GaussianMath Library
/// @notice Mathematical functions for Gaussian (Normal) distribution calculations
/// @dev Builds on Solidity-CDF for core functions and adds additional Gaussian calculations
/// @custom:coauthor @transmissions11 - Fixed-point math patterns
library GaussianFunctions {
    using FixedPointMathLib for int256;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    int256 internal constant ONE = 1e18;
    int256 internal constant TWO = 2e18;
    int256 internal constant SQRT_2PI = 2_506628274631000502; // √(2π) * 1e18
    int256 internal constant NEGATIVE_EIGHT = -8e18;
    int256 internal constant POSITIVE_EIGHT = 8e18;
    uint256 internal constant PRECISION_THRESHOLD = 1e8; // Precision for binary search in PPF

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PPF_INPUT_TOO_LOW();
    error PPF_INPUT_TOO_HIGH();

    /*//////////////////////////////////////////////////////////////
                            GAUSSIAN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes the Percent Point Function (Inverse CDF)
    /// @dev Uses binary search with configurable precision
    /// @param p Probability value in WAD (between 0 and 1e18)
    /// @return Inverse CDF value in WAD
    function ppf(int256 p) public pure returns (int256) {
        if (p <= 0) revert PPF_INPUT_TOO_LOW();
        if (p >= ONE) revert PPF_INPUT_TOO_HIGH();

        int256 left = NEGATIVE_EIGHT;
        int256 right = POSITIVE_EIGHT;
        int256 mid;

        for (uint256 i = 0; i < 128; i++) {
            mid = (left + right) / 2;
            uint256 cdfValue = Gaussian.cdf(mid, 0, uint256(ONE));

            if (abs(int256(cdfValue) - p) < int256(PRECISION_THRESHOLD)) {
                return mid;
            }

            if (int256(cdfValue) < p) {
                left = mid;
            } else {
                right = mid;
            }
        }
        return mid;
    }
    
    /// @notice Computes the Probability Density Function
    /// @dev Uses the standard normal PDF formula: (1/√(2π)) * e^(-x²/2)
    /// @param x Input value in WAD
    /// @return PDF value in WAD
    function pdf(int256 x) public pure returns (int256) {
        int256 xSquared = (x * x) / ONE;
        int256 exponent = -xSquared / 2;

        // Compute e^exponent using rpow
        uint256 eWad = 2_718281828459045e18; // e in WAD format
        uint256 expResult = FixedPointMathLib.rpow(eWad, uint256(exponent < 0 ? -exponent : exponent), uint256(ONE));

        // If the exponent is negative, take the reciprocal
        if (exponent < 0) {
            expResult = uint256(1e36) / expResult; // Adjust for WAD precision
        }

        // Perform division using unsigned values and then convert back to signed
        uint256 pdfValue = (uint256(ONE) * expResult) / uint256(SQRT_2PI);
        
        return int256(pdfValue);
    }

    /// @notice Computes the Standard Normal CDF
    /// @dev Wrapper around Solidity-CDF's Gaussian.cdf
    /// @param x Input value in WAD
    /// @return CDF value in WAD
    function cdf(int256 x) public pure returns (uint256) {
        return Gaussian.cdf(x, 0, uint256(ONE));
    }

    /// @notice Computes the Error Function
    /// @dev erf(x) = 1 - erfc(x)
    /// @param x Input value in WAD
    /// @return Error function value in WAD
    function erf(int256 x) public pure returns (int256) {
        return ONE - int256(Gaussian.erfc(x));
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes the absolute value of an integer
    /// @param x Input value
    /// @return Absolute value
    function abs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    /// @notice Converts an unsigned integer to a signed integer
    /// @param x Unsigned integer
    /// @return Signed integer
    function toInt(uint256 x) internal pure returns (int256) {
        require(x <= uint256(type(int256).max), "INT_OVERFLOW");
        return int256(x);
    }

    /// @notice Converts a signed integer to an unsigned integer
    /// @param x Signed integer
    /// @return Unsigned integer
    function toUint(int256 x) internal pure returns (uint256) {
        require(x >= 0, "NEGATIVE_VALUE");
        return uint256(x);
    }
}

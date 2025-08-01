// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "../libraries/MakerTraitsLib.sol";
import "../libraries/TakerTraitsLib.sol";

/**
 * @title IOrderMixin
 * @notice Interface for order processing logic in the 1inch Limit Order Protocol.
 */
interface IOrderMixin {
    struct Order {
        uint256 salt;
        Address maker;
        Address receiver;
        Address makerAsset;
        Address takerAsset;
        uint256 makingAmount;
        uint256 takingAmount;
        MakerTraits makerTraits;
    }

    error InvalidatedOrder();
    error TakingAmountExceeded();
    error PrivateOrder();
    error BadSignature();
    error OrderExpired();
    error WrongSeriesNonce();
    error SwapWithZeroAmount();
    error PartialFillNotAllowed();
    error OrderIsNotSuitableForMassInvalidation();
    error EpochManagerAndBitInvalidatorsAreIncompatible();
    error ReentrancyDetected();
    error PredicateIsNotTrue();
    error TakingAmountTooHigh();
    error MakingAmountTooLow();
    error TransferFromMakerToTakerFailed();
    error TransferFromTakerToMakerFailed();
    error MismatchArraysLengths();
    error InvalidPermit2Transfer();
    error SimulationResults(bool success, bytes res);

    /**
     * @notice Emitted when order gets filled
     * @param orderHash Hash of the order
     * @param remainingAmount Amount of the maker asset that remains to be filled
     */
    event OrderFilled(
        bytes32 orderHash,
        uint256 remainingAmount
    );

    /**
     * @notice Emitted when order without `useBitInvalidator` gets cancelled
     * @param orderHash Hash of the order
     */
    event OrderCancelled(
        bytes32 orderHash
    );

    /**
     * @notice Emitted when order with `useBitInvalidator` gets cancelled
     * @param maker Maker address
     * @param slotIndex Slot index that was updated
     * @param slotValue New slot value
     */
    event BitInvalidatorUpdated(
        address indexed maker,
        uint256 slotIndex,
        uint256 slotValue
    );

    // /**
    //  * @notice Delegates execution to custom implementation. Could be used to validate if `transferFrom` works properly
    //  * @dev The function always reverts and returns the simulation results in revert data.
    //  * @param target Addresses that will be delegated
    //  * @param data Data that will be passed to delegatee
    //  */
    // function simulate(address target, bytes calldata data) external;

    /**
     * @notice Cancels order's quote
     * @param makerTraits Order makerTraits
     * @param orderHash Hash of the order to cancel
     */
    function cancelOrder(MakerTraits makerTraits, bytes32 orderHash) external;



    /**
     * @notice Fills order's quote, fully or partially (whichever is possible).
     * @param order Order quote to fill
     * @param r R component of signature
     * @param vs VS component of signature
     * @param amount Taker amount to fill
     * @param takerTraits Specifies threshold as maximum allowed takingAmount when takingAmount is zero, otherwise specifies
     * minimum allowed makingAmount. The 2nd (0 based index) highest bit specifies whether taker wants to skip maker's permit.
     * @return makingAmount Actual amount transferred from maker to taker
     * @return takingAmount Actual amount transferred from taker to maker
     * @return orderHash Hash of the filled order
     */
    function fillOrder(
        Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits
    ) external payable returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);


    /**
     * @notice Returns order hash, hashed with limit order protocol contract EIP712
     * @param order Order
     * @return orderHash Hash of the order
     */
    function hashOrder(IOrderMixin.Order calldata order) external view returns(bytes32 orderHash);
}

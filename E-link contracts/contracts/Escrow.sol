// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Interfaces/IERC20.sol";

/**
 * @title Escrow
 * @dev Base contract supports both native currency and ERC20 tokens.
 */
abstract contract Escrow {
    // --- State Variables ---
    address public immutable taker;
    address public immutable maker;
    bytes32 public immutable secretHash;
    uint256 public immutable timeout;
    IERC20 public immutable tokenContract;
    uint256 public immutable amount;

    // --- Events ---
    event Withdrawn(bytes32 secret);
    event Cancelled();

    // --- Constructor ---
    constructor(
        address _taker,
        address _maker,
        bytes32 _secretHash,
        uint256 _timeout,
        address _tokenContract,
        uint256 _amount
    ) {
        require(_amount > 0, "Escrow: amount must be positive");
        require(_timeout > block.timestamp, "Escrow: timeout must be in future");
        
        taker = _taker;
        maker = _maker;
        secretHash = _secretHash;
        timeout = _timeout;
        tokenContract = IERC20(_tokenContract);
        amount = _amount;
    }

    // --- Core Logic Functions ---
    /**
     * @dev Internal function to securely transfer the held funds to a recipient.
     */
    function _transferFunds(address recipient) internal {
        if (address(tokenContract) == address(0)) {
            // This is a native currency transfer
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "Escrow: native transfer failed");
        } else {
            // This is an ERC20 token transfer
            bool success = tokenContract.transfer(recipient, amount);
            require(success, "Escrow: ERC20 transfer failed");
        }
    }

    function _withdraw(bytes32 secret) internal {
        require(block.timestamp <= timeout, "Escrow: timeout has passed");
        require(sha256(abi.encodePacked(secret)) == secretHash, "Escrow: invalid secret");
        _transferFunds(taker); // Transfer to the taker
        emit Withdrawn(secret);
    }

    modifier timeoutPassed() {
        require(block.timestamp > timeout, "Escrow: timeout has not passed");
        _;
    }

    function _cancel() internal {
        require(block.timestamp > timeout, "Escrow: timeout has not passed");
        _transferFunds(maker); // Transfer back to the maker
        emit Cancelled();
    }

    function publicWithdraw(bytes32 secret) external timeoutPassed {
        require(sha256(abi.encodePacked(secret)) == secretHash, "Escrow: invalid secret");
        _transferFunds(taker);
        emit Withdrawn(secret);
    }

    // Allow contract to receive native currency
    receive() external payable {}
}

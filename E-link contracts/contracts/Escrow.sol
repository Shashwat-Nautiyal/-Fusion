// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Interfaces/IERC20.sol";

/**
 * @title Escrow
 * @dev Base contract for cross-chain atomic swaps.
 * - SrcEscrow: Holds user's tokens, transfers to resolver when secret revealed
 * - DstEscrow: Holds resolver's tokens, transfers to user when secret revealed
 * - Native ETH is used for safety deposits, ERC20 amount is for the actual swap
 */
abstract contract Escrow {
    // --- State Variables ---
    address public immutable taker;        // In SrcEscrow: resolver, In DstEscrow: user
    address public immutable maker;        // In SrcEscrow: user, In DstEscrow: resolver
    bytes32 public immutable secretHash;   // Hash of the secret for atomic swap
    uint256 public immutable timeout;     // Timestamp after which refund is possible
    IERC20 public immutable tokenContract; // ERC20 token contract (address(0) for native ETH)
    uint256 public immutable amount;       // Amount of tokens to swap
    uint256 public immutable safetyDeposit; // Safety deposit amount in native ETH

    bool public withdrawn = false;
    bool public cancelled = false;

    // --- Events ---
    event Withdrawn(bytes32 secret, address recipient);
    event Cancelled(address recipient);

    // --- Constructor ---
    constructor(
        address _taker,
        address _maker,
        bytes32 _secretHash,
        uint256 _timeout,
        address _tokenContract,
        uint256 _amount,
        uint256 _safetyDeposit
    ) {
        require(_amount > 0, "Escrow: amount must be positive");
        require(_timeout > block.timestamp, "Escrow: timeout must be in future");
        require(_safetyDeposit > 0, "Escrow: safety deposit must be positive");
        
        taker = _taker;
        maker = _maker;
        secretHash = _secretHash;
        timeout = _timeout;
        tokenContract = IERC20(_tokenContract);
        amount = _amount;
        safetyDeposit = _safetyDeposit;
    }

    // --- Modifiers ---
    modifier notWithdrawn() {
        require(!withdrawn, "Escrow: already withdrawn");
        _;
    }

    modifier notCancelled() {
        require(!cancelled, "Escrow: already cancelled");
        _;
    }

    modifier timeoutPassed() {
        require(block.timestamp > timeout, "Escrow: timeout has not passed");
        _;
    }

    modifier timeoutNotPassed() {
        require(block.timestamp <= timeout, "Escrow: timeout has passed");
        _;
    }

    // --- Core Logic Functions ---
    /**
     * @dev Internal function to securely transfer the held funds to a recipient.
     */
    function _transferFunds(address recipient) internal {
        if (address(tokenContract) == address(0)) {
            // This is a native currency transfer (amount includes safety deposit)
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "Escrow: native transfer failed");
        } else {
            // This is an ERC20 token transfer + native ETH safety deposit
            bool success = tokenContract.transfer(recipient, amount);
            require(success, "Escrow: ERC20 transfer failed");
            
            // Return safety deposit
            (bool ethSuccess, ) = recipient.call{value: safetyDeposit}("");
            require(ethSuccess, "Escrow: safety deposit return failed");
        }
    }

    /**
     * @dev Internal function to return funds to maker (refund)
     */
    function _refundFunds() internal {
        if (address(tokenContract) == address(0)) {
            // Native currency refund
            (bool success, ) = maker.call{value: amount}("");
            require(success, "Escrow: native refund failed");
        } else {
            // ERC20 refund + safety deposit return
            bool success = tokenContract.transfer(maker, amount);
            require(success, "Escrow: ERC20 refund failed");
            
            // Return safety deposit to maker
            (bool ethSuccess, ) = maker.call{value: safetyDeposit}("");
            require(ethSuccess, "Escrow: safety deposit refund failed");
        }
    }

    /**
     * @dev Internal withdraw function
     */
    function _withdraw(bytes32 secret) internal timeoutNotPassed notWithdrawn notCancelled {
        require(sha256(abi.encodePacked(secret)) == secretHash, "Escrow: invalid secret");
        withdrawn = true;
        _transferFunds(taker);
        emit Withdrawn(secret, taker);
    }

    /**
     * @dev Internal cancel function
     */
    function _cancel() internal timeoutPassed notWithdrawn notCancelled {
        cancelled = true;
        _refundFunds();
        emit Cancelled(maker);
    }

    /**
     * @dev Public withdraw function (anyone can call after timeout with correct secret)
     */
    function publicWithdraw(bytes32 secret) external timeoutPassed notWithdrawn notCancelled {
        require(sha256(abi.encodePacked(secret)) == secretHash, "Escrow: invalid secret");
        withdrawn = true;
        _transferFunds(taker);
        emit Withdrawn(secret, taker);
    }

    /**
     * @dev Check contract balance
     */
    function getContractBalance() external view returns (uint256 tokenBalance, uint256 ethBalance) {
        if (address(tokenContract) == address(0)) {
            return (0, address(this).balance);
        } else {
            return (tokenContract.balanceOf(address(this)), address(this).balance);
        }
    }

    // Allow contract to receive native currency
    receive() external payable {}
}
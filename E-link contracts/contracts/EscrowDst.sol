// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Escrow.sol";

/**
 * @title EscrowDst
 * @dev Destination chain escrow contract for cross-chain atomic swaps
 * 
 * Flow:
 * 1. Resolver (maker) deposits tokens + safety deposit
 * 2. User (taker) can withdraw tokens by revealing the same secret
 * 3. If timeout passes, anyone can cancel and refund to resolver
 * 
 * Token flow: Resolver -> User
 */
contract EscrowDst is Escrow {
    constructor(
        address _taker,      // user address
        address _maker,      // resolver address
        bytes32 _secretHash, // same secret hash as SrcEscrow
        uint256 _timeout,
        address _tokenContract,
        uint256 _amount,     // amount of ERC20 tokens (or ETH if tokenContract == 0)
        uint256 _safetyDeposit // safety deposit in native ETH
    ) Escrow(_taker, _maker, _secretHash, _timeout, _tokenContract, _amount, _safetyDeposit) {}

    /**
     * @dev User withdraws resolver's tokens by revealing secret
     * Only user (taker) can call this before timeout
     */
    function withdraw(bytes32 secret) external {
        require(msg.sender == taker, "EscrowDst: caller is not the user");
        _withdraw(secret);
    }

    /**
     * @dev Cancel escrow and refund to resolver after timeout
     * Anyone can call this after timeout
     */
    function publicCancel() external {
        _cancel();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Escrow.sol";

/**
 * @title EscrowSrc
 * @dev Source chain escrow contract for cross-chain atomic swaps
 * 
 * Flow:
 * 1. User (maker) deposits tokens + safety deposit
 * 2. Resolver (taker) can withdraw tokens by revealing secret
 * 3. If timeout passes, anyone can cancel and refund to user
 * 
 * Token flow: User -> Resolver
 */
contract EscrowSrc is Escrow {
    constructor(
        address _taker,      // resolver address
        address _maker,      // user address  
        bytes32 _secretHash,
        uint256 _timeout,
        address _tokenContract,
        uint256 _amount,     // amount of ERC20 tokens (or ETH if tokenContract == 0)
        uint256 _safetyDeposit // safety deposit in native ETH
    ) Escrow(_taker, _maker, _secretHash, _timeout, _tokenContract, _amount, _safetyDeposit) {}

    /**
     * @dev Resolver withdraws user's tokens by revealing secret
     * Only resolver (taker) can call this before timeout
     */
    function withdraw(bytes32 secret) external {
        require(msg.sender == taker, "EscrowSrc: caller is not the resolver");
        _withdraw(secret);
    }

    /**
     * @dev Cancel escrow and refund to user after timeout
     * Anyone can call this after timeout
     */
    function publicCancel() external {
        _cancel();
    }
}
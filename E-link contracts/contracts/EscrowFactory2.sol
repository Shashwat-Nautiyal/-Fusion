// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ResolverRegistry.sol" ;
import "./EscrowSrc.sol";
import "./EscrowDst.sol";

/// @notice Factory to deploy escrows on this chain.
contract EscrowFactory {
    address public registry; 
    event EscrowSrcCreated(address indexed escrow);
    event EscrowDstCreated(address indexed escrow);

    constructor(address registry_) {
        require(registry_ != address(0), "Invalid registry address");
        registry = registry_;
    }

    /// @notice Create a source-chain escrow.
    /// @param maker The user who wants to swap out of this chain.
    /// @param resolver The resolver executing the swap.
    /// @param token Address of the ERC20 to be swapped.
    /// @param amount Amount of maker's tokens to lock.
    /// @param deposit Safety deposit (in native currency) from resolver.
    /// @param secretHash Hash of the secret linking both escrows.
    /// @param timelock Unix timestamp after which a refund can be triggered.
    function createEscrowSrc(
        address maker,
        address resolver,
        IERC20 token,
        uint256 amount,
        uint256 deposit,
        bytes32 secretHash,
        uint256 timelock
    ) external returns (address) {
        // Input validation
        require(maker != address(0), "Invalid maker address");
        require(resolver != address(0), "Invalid resolver address");
        require(address(token) != address(0), "Invalid token address");
        require(amount > 0, "Amount must be positive");
        require(timelock > block.timestamp, "Invalid timelock");
        
        // Only allow authorized resolvers
        require(ResolverRegistry(registry).isResolver(msg.sender), "Not authorized resolver");
        
        EscrowSrc escrow = new EscrowSrc(
            maker, resolver, token, amount, deposit, secretHash, timelock
        );
        emit EscrowSrcCreated(address(escrow));
        return address(escrow);
    }

    /// @notice Create a destination-chain escrow.
    /// @param maker The user who wants to swap out of this chain.
    /// @param resolver The resolver executing the swap.
    /// @param token Address of the ERC20 to be swapped.
    /// @param amount Amount of maker's tokens to lock.
    /// @param deposit Safety deposit (in native currency) from resolver.
    /// @param secretHash Hash of the secret linking both escrows.
    /// @param timelock Unix timestamp after which a refund can be triggered.
    function createEscrowDst(
        address maker,
        address resolver,
        IERC20 token,
        uint256 amount,
        uint256 deposit,
        bytes32 secretHash,
        uint256 timelock
    ) external returns (address) {
        // Input validation
        require(maker != address(0), "Invalid maker address");
        require(resolver != address(0), "Invalid resolver address");
        require(address(token) != address(0), "Invalid token address");
        require(amount > 0, "Amount must be positive");
        require(timelock > block.timestamp, "Invalid timelock");
        
        // Only allow authorized resolvers
        require(ResolverRegistry(registry).isResolver(msg.sender), "Not authorized resolver");
        
        EscrowDst escrow = new EscrowDst(
            maker, resolver, token, amount, deposit, secretHash, timelock
        );
        emit EscrowDstCreated(address(escrow));
        return address(escrow);
    }
}
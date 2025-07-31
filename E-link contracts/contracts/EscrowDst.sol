// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Destination-chain escrow holding the resolver’s tokens + deposit.
contract EscrowDst {
    address public maker;
    address public resolver;
    IERC20 public token;
    uint256 public amount;       // Resolver’s token amount
    uint256 public deposit;      // Resolver’s safety deposit
    bytes32 public secretHash;
    uint256 public timelock;     // Expiration time
    bool public funded;
    bool public completed;

    constructor(
        address _maker,
        address _resolver,
        IERC20 _token,
        uint256 _amount,
        uint256 _deposit,
        bytes32 _secretHash,
        uint256 _timelock
    ) {
        maker = _maker;
        resolver = _resolver;
        token = _token;
        amount = _amount;
        deposit = _deposit;
        secretHash = _secretHash;
        timelock = _timelock;
    }

    /// @notice Resolver funds the destination escrow.
    function fund() external payable {
        require(msg.sender == resolver, "Only resolver");
        require(!funded, "Already funded");
        require(msg.value == deposit, "Wrong deposit");
        require(token.transferFrom(resolver, address(this), amount), "Token transfer failed");
        funded = true;
    }

    /// @notice Resolver uses secret to send tokens to maker (before timelock).
    function unlock(bytes calldata secret) external {
        require(!completed, "Already completed");
        require(msg.sender == resolver, "Only resolver");
        require(funded, "Not funded");
        require(block.timestamp < timelock, "Timelock passed");
        require(keccak256(secret) == secretHash, "Invalid secret");
        // Send resolver's tokens to maker
        token.transfer(maker, amount);
        // Return safety deposit to resolver
        payable(resolver).transfer(deposit);
        completed = true;
    }

    /// @notice After timelock, anyone can refund (resolver reclaims funds).
    function refund() external {
        require(!completed, "Already completed");
        require(funded, "Not funded");
        require(block.timestamp >= timelock, "Too early to refund");
        // Return resolver's tokens to resolver
        token.transfer(resolver, amount);
        // Return deposit to resolver
        payable(resolver).transfer(deposit);
        completed = true;
    }
}

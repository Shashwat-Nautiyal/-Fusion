// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Source-chain escrow holding the maker’s tokens + resolver’s deposit.
contract EscrowSrc {
    address public maker;
    address public resolver;
    IERC20 public token;
    uint256 public amount;       // Maker’s token amount
    uint256 public deposit;      // Resolver’s safety deposit (in native currency)
    bytes32 public secretHash;
    uint256 public timelock;     // Expiration time (Unix timestamp)
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

    /// @notice Resolver funds the escrow: transfers maker’s tokens in and sends deposit.
    function fund() external payable {
        require(msg.sender == resolver, "Only resolver");
        require(!funded, "Already funded");
        require(msg.value == deposit, "Wrong deposit");
        require(token.transferFrom(maker, address(this), amount), "Token transfer failed");
        funded = true;
    }

    /// @notice Resolver reveals secret to claim maker’s tokens (before timelock).
    function unlock(bytes calldata secret) external {
        require(!completed, "Already completed");
        require(msg.sender == resolver, "Only resolver");
        require(funded, "Not funded");
        require(block.timestamp < timelock, "Timelock passed");
        require(keccak256(secret) == secretHash, "Invalid secret");
        // Send maker's tokens to resolver
        token.transfer(resolver, amount);
        // Return safety deposit to resolver
        payable(resolver).transfer(deposit);
        completed = true;
    }

    /// @notice After timelock, anyone can refund: return tokens to maker, slash deposit.
    function refund() external {
        require(!completed, "Already completed");
        require(funded, "Not funded");
        require(block.timestamp >= timelock, "Too early to refund");
        // Return maker's tokens to maker
        token.transfer(maker, amount);
        // Safety deposit goes to caller (executor) or to maker if resolver calls
        if (msg.sender == resolver) {
            // If resolver triggers cancel, deposit to maker as penalty
            payable(maker).transfer(deposit);
        } else {
            // Otherwise, caller (likely maker or third-party) gets deposit
            payable(msg.sender).transfer(deposit);
        }
        completed = true;
    }
}

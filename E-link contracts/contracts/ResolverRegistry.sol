// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
}

/// @notice Resolver registry managing authorized resolver addresses.
contract ResolverRegistry {
    address public owner;
    mapping(address => bool) public isResolver;
    constructor() { owner = msg.sender; }
    function addResolver(address resolver) external {
        require(msg.sender == owner, "Only owner");
        isResolver[resolver] = true;
    }
    function removeResolver(address resolver) external {
        require(msg.sender == owner, "Only owner");
        isResolver[resolver] = false;
    }
}

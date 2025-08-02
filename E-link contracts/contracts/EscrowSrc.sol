// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Escrow.sol";

contract EscrowSrc is Escrow {
    constructor(
        address _taker,
        address _maker,
        bytes32 _secretHash,
        uint256 _timeout,
        address _tokenContract,
        uint256 _amount
    ) Escrow(_taker, _maker, _secretHash, _timeout, _tokenContract, _amount) {}

    function withdraw(bytes32 secret) external {
        require(msg.sender == taker, "EscrowSrc: caller is not the taker");
        _withdraw(secret);
    }

    function publicCancel() external {
        _cancel();
    }
}

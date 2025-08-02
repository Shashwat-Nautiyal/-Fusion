// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Resolver.sol";

contract ResolverTest is Test {
    Resolver public resolver;
    EscrowFactory public factory;
    address public owner = address(this);
    address public taker = address(0xBEEF);
    address public maker = address(0xCAFE);
    address public token = address(0); // Native ETH
    uint256 public amount = 1 ether;
    bytes32 public secret = keccak256("secret");
    bytes32 public secretHash = sha256(abi.encodePacked(secret));
    uint256 public timeout = 1000 + block.timestamp;
    bytes32 public salt = keccak256("salt");

    function setUp() public {
        factory = new EscrowFactory();
        resolver = new Resolver(factory, owner);
        vm.deal(maker, 10 ether);
        vm.deal(address(resolver), 10 ether);
    }

    function testOwnershipTransfer() public {
        address newOwner = address(0xB0B);
        resolver.transferOwnership(newOwner);
        assertEq(resolver.owner(), newOwner);
    }

    function testDeploySrcEscrow() public {
        vm.prank(owner);
        address escrow = resolver.deploySrcEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        assertEq(escrow, factory.addressOfEscrowSrc(taker, maker, secretHash, timeout, token, amount, salt));
    }

    function testDeployDstEscrow() public {
        vm.prank(owner);
        address escrow = resolver.deployDstEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        assertEq(escrow, factory.addressOfEscrowDst(taker, maker, secretHash, timeout, token, amount, salt));
    }

    function testWithdrawSrc() public {
        address escrow = resolver.deploySrcEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        vm.prank(owner);
        resolver.withdrawFromSrc(payable(escrow), secret);
    }

    function testWithdrawDst() public {
        address escrow = resolver.deployDstEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        vm.prank(owner);
        resolver.withdrawFromDst(payable(escrow), secret);
    }

    function testCancelSrcAfterTimeout() public {
        address escrow = resolver.deploySrcEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        vm.warp(timeout + 1);
        vm.prank(taker);
        resolver.cancelSrc(payable(escrow));
    }

    function testCancelDstAfterTimeout() public {
        address escrow = resolver.deployDstEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        vm.warp(timeout + 1);
        vm.prank(maker);
        resolver.cancelDst(payable(escrow));
    }

    function testVerifySecret() public {
        bool valid = resolver.verifySecret(secret, secretHash);
        assertTrue(valid);
    }

    function testEmergencyWithdrawETH() public {
        uint256 balBefore = address(owner).balance;
        vm.prank(owner);
        resolver.emergencyWithdraw(address(0), 1 ether);
        assertEq(address(owner).balance, balBefore + 1 ether);
    }

    function testGetEscrowInfo() public {
        address escrow = resolver.deploySrcEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        (
            address _taker,
            address _maker,
            bytes32 _secretHash,
            uint256 _timeout,
            address _token,
            uint256 _amount
        ) = resolver.getEscrowInfo(payable(escrow));
        assertEq(_taker, taker);
        assertEq(_maker, maker);
        assertEq(_secretHash, secretHash);
        assertEq(_timeout, timeout);
        assertEq(_token, token);
        assertEq(_amount, amount);
    }

    function testIsTimeoutPassed() public {
        address escrow = resolver.deploySrcEscrow{value: amount}(
            taker, maker, secretHash, timeout, token, amount, salt
        );
        vm.warp(timeout + 1);
        assertTrue(resolver.isTimeoutPassed(payable(escrow)));
    }
}

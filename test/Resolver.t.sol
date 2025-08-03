// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Resolver.sol";
import "../E-link contracts/contracts/EscrowFactory.sol";
import "../E-link contracts/contracts/EscrowSrc.sol";
import "../E-link contracts/contracts/EscrowDst.sol";

// Mock ERC20 token for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name = "MockToken";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;
    
    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract ResolverTest is Test {
    Resolver public resolver;
    EscrowFactory public factory;
    MockERC20 public token;
    
    address public owner = address(this);
    address public user = address(0xBEEF);
    address public resolver_addr;
    
    uint256 public srcAmount = 1000 * 10**18; // 1000 tokens
    uint256 public dstAmount = 2 ether;       // 2 ETH
    uint256 public safetyDeposit = 0.1 ether; // 0.1 ETH safety deposit
    
    bytes32 public secret = keccak256("secret123");
    bytes32 public secretHash = sha256(abi.encodePacked(secret));
    uint256 public timeout = 1000 + block.timestamp;
    bytes32 public salt = keccak256("salt123");

    function setUp() public {
        // Deploy contracts
        factory = new EscrowFactory();
        resolver = new Resolver(factory, owner);
        resolver_addr = address(resolver);
        token = new MockERC20();
        
        // Fund accounts
        vm.deal(user, 10 ether);
        vm.deal(resolver_addr, 10 ether);
        vm.deal(address(this), 10 ether);
        
        // Give tokens to user and resolver
        token.transfer(user, 5000 * 10**18);
        token.transfer(resolver_addr, 5000 * 10**18);
    }

    function testOwnershipTransfer() public {
        address newOwner = address(0xB0B);
        resolver.transferOwnership(newOwner);
        assertEq(resolver.owner(), newOwner);
    }

    function testDeploySrcEscrow() public {
        // User approves tokens for escrow factory
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        // Deploy source escrow
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user,           // user
            secretHash,
            timeout,
            address(token), // ERC20 token
            srcAmount,
            safetyDeposit,
            salt
        ));
        
        // Verify source escrow was funded correctly
        assertEq(token.balanceOf(srcEscrow), srcAmount);
        assertEq(srcEscrow.balance, safetyDeposit);
    }

    function testDeployDstEscrow() public {
        // Resolver approves tokens for factory (resolver needs to approve)
        token.approve(address(factory), dstAmount);
        
        // Deploy destination escrow
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user,           // user will receive
            secretHash,     // same secret hash
            timeout,
            address(0),     // native ETH
            dstAmount,
            safetyDeposit,
            salt
        ));
        
        // Verify destination escrow was funded correctly
        assertEq(dstEscrow.balance, dstAmount + safetyDeposit);
    }

    function testSrcEscrowWithdraw() public {
        // User approves and creates source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        // Resolver withdraws using secret
        uint256 resolverTokenBalanceBefore = token.balanceOf(resolver_addr);
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        
        resolver.withdrawFromSrc(srcEscrow, secret);
        
        // Verify resolver received tokens + safety deposit
        assertEq(token.balanceOf(resolver_addr), resolverTokenBalanceBefore + srcAmount);
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + safetyDeposit);
    }

    function testDstEscrowWithdraw() public {
        // Deploy destination escrow with ETH
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, salt
        ));
        
        // User withdraws ETH using secret
        uint256 userEthBalanceBefore = user.balance;
        
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        
        // Verify user received ETH + safety deposit
        assertEq(user.balance, userEthBalanceBefore + dstAmount);
    }

    function testCancelSrcAfterTimeout() public {
        // User creates source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        // Fast forward past timeout
        vm.warp(timeout + 1);
        
        // Cancel escrow
        uint256 userTokenBalanceBefore = token.balanceOf(user);
        uint256 userEthBalanceBefore = user.balance;
        
        resolver.cancelSrc(srcEscrow);
        
        // Verify user got refund
        assertEq(token.balanceOf(user), userTokenBalanceBefore + srcAmount);
        assertEq(user.balance, userEthBalanceBefore + safetyDeposit);
    }

    function testCancelDstAfterTimeout() public {
        // Deploy destination escrow
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, salt
        ));
        
        // Fast forward past timeout
        vm.warp(timeout + 1);
        
        // Cancel escrow
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        
        resolver.cancelDst(dstEscrow);
        
        // Verify resolver got refund
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + dstAmount );
    }

    function testPublicWithdrawAfterTimeout() public {
        // User creates source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        // Fast forward past timeout
        vm.warp(timeout + 1);
        
        // Anyone can withdraw with correct secret after timeout
        uint256 resolverTokenBalanceBefore = token.balanceOf(resolver_addr);
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        
        vm.prank(address(0x123)); // Random address
        resolver.publicWithdraw(srcEscrow, secret);
        
        // Resolver should receive the funds (taker in src escrow)
        assertEq(token.balanceOf(resolver_addr), resolverTokenBalanceBefore + srcAmount);
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + safetyDeposit);
    }

    function testGetEscrowInfo() public {
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        (
            address taker,
            address maker,
            bytes32 _secretHash,
            uint256 _timeout,
            address tokenContract,
            uint256 amount,
            uint256 _safetyDeposit
        ) = resolver.getEscrowInfo(srcEscrow);
        
        assertEq(taker, resolver_addr); // resolver is taker in src escrow
        assertEq(maker, user);          // user is maker in src escrow
        assertEq(_secretHash, secretHash);
        assertEq(_timeout, timeout);
        assertEq(tokenContract, address(token));
        assertEq(amount, srcAmount);
        assertEq(_safetyDeposit, safetyDeposit);
    }

    function testVerifySecret() public view {
        assertTrue(resolver.verifySecret(secret, secretHash));
        assertFalse(resolver.verifySecret(keccak256("wrong"), secretHash));
    }

    function testIsTimeoutPassed() public {
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        assertFalse(resolver.isTimeoutPassed(srcEscrow));
        
        vm.warp(timeout + 1);
        assertTrue(resolver.isTimeoutPassed(srcEscrow));
    }

    function testEmergencyWithdrawETH() public {
        uint256 balBefore = address(owner).balance;
        resolver.emergencyWithdraw(address(0), 1 ether);
        assertEq(address(owner).balance, balBefore + 1 ether);
    }

    function testEmergencyWithdrawERC20() public {
        // Send some tokens to resolver
        token.transfer(resolver_addr, 100 * 10**18);
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        resolver.emergencyWithdraw(address(token), 50 * 10**18);
        
        assertEq(token.balanceOf(owner), ownerBalanceBefore + 50 * 10**18);
    }

    function testCompleteSwapFunction() public {
        // Setup source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        // Setup destination escrow
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, keccak256("salt2")
        ));
        
        // User withdraws from destination first
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        
        // Resolver completes swap
        uint256 balanceBefore = token.balanceOf(resolver_addr);
        resolver.completeSwap(srcEscrow, dstEscrow, secret);
        
        assertEq(token.balanceOf(resolver_addr), balanceBefore + srcAmount);
    }

    receive() external payable {}
}
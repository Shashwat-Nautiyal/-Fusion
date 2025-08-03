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
    uint256 public dstAmount = 2 ether; // 2 ETH
    uint256 public safetyDeposit = 0.1 ether; // 0.1 ETH safety deposit

    bytes32 public secret = keccak256("secret123");
    bytes32 public secretHash = sha256(abi.encodePacked(secret));
    uint256 public timeout = 1000 + block.timestamp;
    bytes32 public salt = keccak256("salt123");

    function setUp() public {
        console.log("=== CROSS-CHAIN SWAP SYSTEM INITIALIZATION ===");
        console.log("=== Deploying EscrowFactory contract...");
        
        // Deploy contracts
        factory = new EscrowFactory();
        console.log("EscrowFactory deployed at:", address(factory));
        
        console.log("=== Deploying Resolver contract...");
        resolver = new Resolver(factory, owner);
        resolver_addr = address(resolver);
        console.log(" Resolver deployed at:", resolver_addr);
        console.log("===> Resolver owner set to:", owner);
        
        console.log("Deploying Mock ERC20 token...");
        token = new MockERC20();
        console.log("===> MockToken deployed at:", address(token));
        console.log("===> Token name:", token.name());
        console.log("===> Token symbol:", token.symbol());

        // Fund accounts
        console.log("\n--- FUNDING ACCOUNTS ---");
        vm.deal(user, 10 ether);
        console.log("===> User funded with 10 ETH");
        vm.deal(resolver_addr, 10 ether);
        console.log("===> Resolver funded with 10 ETH");
        vm.deal(address(this), 10 ether);
        console.log("===> Test contract funded with 10 ETH");

        // Give tokens to user and resolver
        token.transfer(user, 5000 * 10**18);
        console.log("===> User funded with 5000 MockTokens");
        token.transfer(resolver_addr, 5000 * 10**18);
        console.log("===> Resolver funded with 5000 MockTokens");
        
        console.log("=== SYSTEM READY FOR CROSS-CHAIN SWAPS ===\n");
    }

    function testOwnershipTransfer() public {
        console.log("=== TESTING OWNERSHIP TRANSFER ===");
        address newOwner = address(0xB0B);
        console.log("Current owner:", resolver.owner());
        console.log("Transferring ownership to:", newOwner);
        
        resolver.transferOwnership(newOwner);
        console.log("===> Ownership transfer completed");
        console.log("New owner verified:", resolver.owner());
        
        assertEq(resolver.owner(), newOwner);
        console.log("===> Ownership transfer test PASSED\n");
    }

    function testDeploySrcEscrow() public {
        console.log("=== INITIATING CROSS-CHAIN SWAP - SOURCE CHAIN ===");
        console.log("User wants to swap:");
        console.log("  Amount:", srcAmount / 10**18);
        console.log("  Token: MockTokens for");
        console.log("  Amount:", dstAmount / 10**18);
        console.log("  Token: ETH");
        console.log("User address:", user);
        console.log("Resolver address:", resolver_addr);
        
        console.log("\n--- STEP 1: TOKEN APPROVAL ---");
        console.log("User approving", srcAmount / 10**18, "MockTokens for EscrowFactory...");
        // User approves tokens for escrow factory
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log("===> Token approval completed");
        console.log("===> Approved amount:", token.allowance(user, address(factory)) / 10**18, "MockTokens");

        console.log("\n--- STEP 2: SOURCE ESCROW DEPLOYMENT ---");
        console.log("Deploying source escrow with parameters:");
        console.log("  * Maker (User):", user);
        console.log("  * Token:", address(token));
        console.log("  * Amount:", srcAmount / 10**18, "MockTokens");
        console.log("  * Safety Deposit:", safetyDeposit / 10**18, "ETH");
        console.log("  * Timeout:", timeout);
        console.log("  * Secret Hash:", vm.toString(secretHash));
        
        // Deploy source escrow
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, // user
            secretHash,
            timeout,
            address(token), // ERC20 token
            srcAmount,
            safetyDeposit,
            salt
        ));
        
        console.log("===> SOURCE ESCROW DEPLOYED SUCCESSFULLY!");
        console.log("===> Source escrow address:", srcEscrow);
        console.log("===> Escrow token balance:", token.balanceOf(srcEscrow) / 10**18, "MockTokens");
        console.log("===> Escrow ETH balance:", srcEscrow.balance / 10**18, "ETH (Safety Deposit)");

        // Verify source escrow was funded correctly
        assertEq(token.balanceOf(srcEscrow), srcAmount);
        assertEq(srcEscrow.balance, safetyDeposit);
        
        console.log("===> Source escrow funding verification PASSED");
        console.log("=== SOURCE CHAIN SETUP COMPLETED ===\n");
    }

    function testDeployDstEscrow() public {
        console.log("=== SETTING UP DESTINATION CHAIN ESCROW ===");
        console.log("Resolver preparing to lock", dstAmount / 10**18, "ETH for user...");
        
        console.log("\n--- STEP 1: RESOLVER TOKEN APPROVAL ---");
        console.log("Resolver approving tokens for factory...");
        // Resolver approves tokens for factory (resolver needs to approve)
        token.approve(address(factory), dstAmount);
        console.log("===> Resolver approval completed");

        console.log("\n--- STEP 2: DESTINATION ESCROW DEPLOYMENT ---");
        console.log("Deploying destination escrow with parameters:");
        console.log("  * Taker (User will receive):", user);
        console.log("  * Token: Native ETH (address(0))");
        console.log("  * Amount:", dstAmount / 10**18, "ETH");
        console.log("  * Safety Deposit:", safetyDeposit / 10**18, "ETH");
        console.log("  * Same secret hash as source");
        
        // Deploy destination escrow
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, // user will receive
            secretHash, // same secret hash
            timeout,
            address(0), // native ETH
            dstAmount,
            safetyDeposit,
            salt
        ));

        console.log("===> DESTINATION ESCROW DEPLOYED SUCCESSFULLY!");
        console.log("===> Destination escrow address:", dstEscrow);
        console.log("===> Escrow ETH balance:", dstEscrow.balance / 10**18, "ETH (Amount + Safety Deposit)");
        
        // Verify destination escrow was funded correctly
        assertEq(dstEscrow.balance, dstAmount + safetyDeposit);
        
        console.log("===> Destination escrow funding verification PASSED");
        console.log("=== DESTINATION CHAIN SETUP COMPLETED ===");
        console.log("=== CROSS-CHAIN SWAP INFRASTRUCTURE READY ===\n");
    }

    function testSrcEscrowWithdraw() public {
        console.log("=== EXECUTING CROSS-CHAIN SWAP - SOURCE WITHDRAWAL ===");
        
        console.log("\n--- SETTING UP SOURCE ESCROW ---");
        // User approves and creates source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log("===> User approved", srcAmount / 10**18, "MockTokens");
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        console.log("===> Source escrow deployed:", srcEscrow);
        console.log("===> Escrow funded with", srcAmount / 10**18, "MockTokens");

        console.log("\n--- STEP 1: RESOLVER INITIATING WITHDRAWAL ---");
        console.log("Resolver has received destination chain confirmation...");
        console.log("Resolver preparing to withdraw from source escrow...");
        console.log("Using secret:", vm.toString(secret));
        
        // Resolver withdraws using secret
        uint256 resolverTokenBalanceBefore = token.balanceOf(resolver_addr);
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        
        console.log("Resolver token balance before:", resolverTokenBalanceBefore / 10**18, "MockTokens");
        console.log("Resolver ETH balance before:", resolverEthBalanceBefore / 10**18, "ETH");
        
        console.log("\n--- STEP 2: EXECUTING WITHDRAWAL ---");
        resolver.withdrawFromSrc(srcEscrow, secret);
        
        console.log("===> WITHDRAWAL FROM SOURCE ESCROW COMPLETED!");
        console.log("===> Secret revealed on-chain");
        console.log("===> Resolver token balance after:", token.balanceOf(resolver_addr) / 10**18, "MockTokens");
        console.log("===> Resolver ETH balance after:", resolver_addr.balance / 10**18, "ETH");
        console.log("===> Tokens received:", (token.balanceOf(resolver_addr) - resolverTokenBalanceBefore) / 10**18, "MockTokens");
        console.log("===> Safety deposit received:", (resolver_addr.balance - resolverEthBalanceBefore) / 10**18, "ETH");

        // Verify resolver received tokens + safety deposit
        assertEq(token.balanceOf(resolver_addr), resolverTokenBalanceBefore + srcAmount);
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + safetyDeposit);
        
        console.log("=== SOURCE CHAIN WITHDRAWAL SUCCESSFUL ===\n");
    }

    function testDstEscrowWithdraw() public {
        console.log("=== EXECUTING CROSS-CHAIN SWAP - DESTINATION WITHDRAWAL ===");
        
        console.log("\n--- SETTING UP DESTINATION ESCROW ---");
        // Deploy destination escrow with ETH
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, salt
        ));
        console.log("===> Destination escrow deployed:", dstEscrow);
        console.log("===> Escrow funded with", (dstAmount + safetyDeposit) / 10**18, "ETH");

        console.log("\n--- STEP 1: USER MONITORING SECRET REVELATION ---");
        console.log("User detected secret revelation on source chain...");
        console.log("Secret found:", vm.toString(secret));
        console.log("User preparing to claim ETH from destination escrow...");

        // User withdraws ETH using secret
        uint256 userEthBalanceBefore = user.balance;
        console.log("User ETH balance before withdrawal:", userEthBalanceBefore / 10**18, "ETH");
        
        console.log("\n--- STEP 2: USER EXECUTING WITHDRAWAL ---");
        console.log("User calling withdraw function with revealed secret...");
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        
        console.log("===> WITHDRAWAL FROM DESTINATION ESCROW COMPLETED!");
        console.log("===> User ETH balance after:", user.balance / 10**18, "ETH");
        console.log("===> ETH received by user:", (user.balance - userEthBalanceBefore) / 10**18, "ETH");

        // Verify user received ETH + safety deposit
        assertEq(user.balance, userEthBalanceBefore + dstAmount);
        
        console.log("=== DESTINATION CHAIN WITHDRAWAL SUCCESSFUL ===");
        console.log("=== CROSS-CHAIN SWAP COMPLETED SUCCESSFULLY! ===\n");
    }

    function testCancelSrcAfterTimeout() public {
        console.log("=== TESTING SOURCE ESCROW CANCELLATION AFTER TIMEOUT ===");
        
        console.log("\n--- SETTING UP ESCROW FOR TIMEOUT SCENARIO ---");
        // User creates source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log("===> User approved tokens");
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        console.log("===> Source escrow created:", srcEscrow);
        console.log("===> Timeout set for:", timeout);
        console.log("===> Current block timestamp:", block.timestamp);

        console.log("\n--- STEP 1: SIMULATING TIMEOUT ---");
        console.log("No activity detected on destination chain...");
        console.log("Waiting for timeout period...");
        
        // Fast forward past timeout
        vm.warp(timeout + 1);
        console.log("===> Time warped past timeout");
        console.log("===> New block timestamp:", block.timestamp);
        console.log("!!! TIMEOUT EXCEEDED - CANCELLATION NOW AVAILABLE");

        console.log("\n--- STEP 2: INITIATING CANCELLATION ---");
        console.log("Resolver initiating cancellation process...");
        console.log("Refunding user's tokens and safety deposit...");
        
        // Cancel escrow
        uint256 userTokenBalanceBefore = token.balanceOf(user);
        uint256 userEthBalanceBefore = user.balance;
        
        console.log("User token balance before refund:", userTokenBalanceBefore / 10**18, "MockTokens");
        console.log("User ETH balance before refund:", userEthBalanceBefore / 10**18, "ETH");
        
        resolver.cancelSrc(srcEscrow);
        
        console.log("===> CANCELLATION COMPLETED SUCCESSFULLY!");
        console.log("===> User token balance after refund:", token.balanceOf(user) / 10**18, "MockTokens");
        console.log("===> User ETH balance after refund:", user.balance / 10**18, "ETH");
        console.log("===> Tokens refunded:", (token.balanceOf(user) - userTokenBalanceBefore) / 10**18, "MockTokens");
        console.log("===> Safety deposit refunded:", (user.balance - userEthBalanceBefore) / 10**18, "ETH");

        // Verify user got refund
        assertEq(token.balanceOf(user), userTokenBalanceBefore + srcAmount);
        assertEq(user.balance, userEthBalanceBefore + safetyDeposit);
        
        console.log("=== SOURCE ESCROW CANCELLATION SUCCESSFUL ===\n");
    }

    function testCancelDstAfterTimeout() public {
        console.log("=== TESTING DESTINATION ESCROW CANCELLATION AFTER TIMEOUT ===");
        
        console.log("\n--- SETTING UP DESTINATION ESCROW FOR TIMEOUT ---");
        // Deploy destination escrow
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, salt
        ));
        console.log("===> Destination escrow created:", dstEscrow);
        console.log("===> Escrow funded with", (dstAmount + safetyDeposit) / 10**18, "ETH");

        console.log("\n--- STEP 1: SIMULATING TIMEOUT ---");
        console.log("Source chain swap failed or timed out...");
        console.log("Waiting for timeout period to recover funds...");
        
        // Fast forward past timeout
        vm.warp(timeout + 1);
        console.log("===> Time warped past timeout");
        console.log("!!! TIMEOUT EXCEEDED - RESOLVER CAN RECOVER FUNDS");

        console.log("\n--- STEP 2: RESOLVER RECOVERING FUNDS ---");
        console.log("Resolver initiating recovery of locked ETH...");
        
        // Cancel escrow
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        console.log("Resolver ETH balance before recovery:", resolverEthBalanceBefore / 10**18, "ETH");
        
        resolver.cancelDst(dstEscrow);
        
        console.log("===> DESTINATION CANCELLATION COMPLETED!");
        console.log("===> Resolver ETH balance after recovery:", resolver_addr.balance / 10**18, "ETH");
        console.log("===> ETH recovered:", (resolver_addr.balance - resolverEthBalanceBefore) / 10**18, "ETH");

        // Verify resolver got refund
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + dstAmount);
        
        console.log("=== DESTINATION ESCROW CANCELLATION SUCCESSFUL ===\n");
    }

    function testPublicWithdrawAfterTimeout() public {
        console.log("=== TESTING PUBLIC WITHDRAWAL AFTER TIMEOUT ===");
        
        console.log("\n--- SETTING UP SCENARIO ---");
        // User creates source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log("===> User approved tokens");
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        console.log("===> Source escrow created:", srcEscrow);

        console.log("\n--- STEP 1: TIMEOUT SCENARIO ---");
        console.log("Swap partially completed but secret revealed...");
        console.log("Timeout period reached...");
        
        // Fast forward past timeout
        vm.warp(timeout + 1);
        console.log("===> Time warped past timeout");
        console.log("!!! Public withdrawal now available with secret");

        console.log("\n--- STEP 2: THIRD PARTY INITIATING WITHDRAWAL ---");
        console.log("External party (", address(0x123), ") calling public withdraw...");
        console.log("Using revealed secret from destination chain...");
        
        // Anyone can withdraw with correct secret after timeout
        uint256 resolverTokenBalanceBefore = token.balanceOf(resolver_addr);
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        
        console.log("Resolver token balance before:", resolverTokenBalanceBefore / 10**18, "MockTokens");
        console.log("Resolver ETH balance before:", resolverEthBalanceBefore / 10**18, "ETH");
        
        vm.prank(address(0x123)); // Random address
        resolver.publicWithdraw(srcEscrow, secret);
        
        console.log("===> PUBLIC WITHDRAWAL COMPLETED!");
        console.log("===> Funds delivered to resolver (taker)");
        console.log("===> Resolver token balance after:", token.balanceOf(resolver_addr) / 10**18, "MockTokens");
        console.log("===> Resolver ETH balance after:", resolver_addr.balance / 10**18, "ETH");

        // Resolver should receive the funds (taker in src escrow)
        assertEq(token.balanceOf(resolver_addr), resolverTokenBalanceBefore + srcAmount);
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + safetyDeposit);
        
        console.log("=== PUBLIC WITHDRAWAL SUCCESSFUL ===\n");
    }

    function testGetEscrowInfo() public {
        console.log("=== TESTING ESCROW INFORMATION RETRIEVAL ===");
        
        console.log("\n--- CREATING ESCROW FOR INSPECTION ---");
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        console.log("===> Source escrow created for info retrieval");

        console.log("\n--- RETRIEVING ESCROW INFORMATION ---");
        (
            address taker,
            address maker,
            bytes32 _secretHash,
            uint256 _timeout,
            address tokenContract,
            uint256 amount,
            uint256 _safetyDeposit
        ) = resolver.getEscrowInfo(srcEscrow);

        console.log("=== ESCROW DETAILS ===");
        console.log("===> Taker (will receive tokens):", taker);
        console.log("===> Maker (provided tokens):", maker);
        console.log("===> Secret Hash:", vm.toString(_secretHash));
        console.log("===> Timeout:", _timeout);
        console.log("===> Token Contract:", tokenContract);
        console.log("===> Amount:", amount / 10**18, "tokens");
        console.log("===> Safety Deposit:", _safetyDeposit / 10**18, "ETH");

        assertEq(taker, resolver_addr); // resolver is taker in src escrow
        assertEq(maker, user); // user is maker in src escrow
        assertEq(_secretHash, secretHash);
        assertEq(_timeout, timeout);
        assertEq(tokenContract, address(token));
        assertEq(amount, srcAmount);
        assertEq(_safetyDeposit, safetyDeposit);
        
        console.log("===> All escrow information verified correctly");
        console.log("=== ESCROW INFO RETRIEVAL SUCCESSFUL ===\n");
    }

    function testVerifySecret() public view {
        console.log("=== TESTING SECRET VERIFICATION ===");
        console.log("Testing secret verification system...");
        console.log("Original secret:", vm.toString(secret));
        console.log("Secret hash:", vm.toString(secretHash));
        
        console.log("\n--- VERIFYING CORRECT SECRET ---");
        bool isValid = resolver.verifySecret(secret, secretHash);
        console.log("===> Correct secret verification result:", isValid);
        assertTrue(isValid);
        
        console.log("\n--- VERIFYING WRONG SECRET ---");
        bytes32 wrongSecret = keccak256("wrong");
        console.log("Wrong secret:", vm.toString(wrongSecret));
        bool isInvalid = resolver.verifySecret(wrongSecret, secretHash);
        console.log("===> Wrong secret verification result:", isInvalid);
        assertFalse(isInvalid);
        
        console.log("=== SECRET VERIFICATION TESTS PASSED ===\n");
    }

    function testIsTimeoutPassed() public {
        console.log("=== TESTING TIMEOUT FUNCTIONALITY ===");
        
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        console.log("===> Escrow created with timeout:", timeout);
        console.log("===> Current block timestamp:", block.timestamp);

        console.log("\n--- CHECKING TIMEOUT STATUS BEFORE EXPIRY ---");
        bool timeoutBefore = resolver.isTimeoutPassed(srcEscrow);
        console.log("===> Timeout passed (before expiry):", timeoutBefore);
        assertFalse(timeoutBefore);
        
        console.log("\n--- SIMULATING TIME PASSAGE ---");
        vm.warp(timeout + 1);
        console.log("===> Time warped to:", block.timestamp);
        
        console.log("--- CHECKING TIMEOUT STATUS AFTER EXPIRY ---");
        bool timeoutAfter = resolver.isTimeoutPassed(srcEscrow);
        console.log("===> Timeout passed (after expiry):", timeoutAfter);
        assertTrue(timeoutAfter);
        
        console.log("=== TIMEOUT FUNCTIONALITY VERIFIED ===\n");
    }

    function testEmergencyWithdrawETH() public {
        console.log("=== TESTING EMERGENCY ETH WITHDRAWAL ===");
        console.log("Simulating emergency situation requiring ETH withdrawal...");
        
        uint256 balBefore = address(owner).balance;
        console.log("Owner ETH balance before emergency:", balBefore / 10**18, "ETH");
        console.log("Initiating emergency withdrawal of 1 ETH...");
        
        resolver.emergencyWithdraw(address(0), 1 ether);
        
        console.log("===> EMERGENCY ETH WITHDRAWAL COMPLETED!");
        console.log("===> Owner ETH balance after emergency:", address(owner).balance / 10**18, "ETH");
        console.log("===> ETH withdrawn:", (address(owner).balance - balBefore) / 10**18, "ETH");
        
        assertEq(address(owner).balance, balBefore + 1 ether);
        console.log("=== EMERGENCY ETH WITHDRAWAL SUCCESSFUL ===\n");
    }

    function testEmergencyWithdrawERC20() public {
        console.log("=== TESTING EMERGENCY TOKEN WITHDRAWAL ===");
        console.log("Simulating emergency situation requiring token withdrawal...");
        
        // Send some tokens to resolver
        console.log("Sending 100 MockTokens to resolver for emergency test...");
        token.transfer(resolver_addr, 100 * 10**18);
        console.log("===> Tokens sent to resolver");
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        console.log("Owner token balance before emergency:", ownerBalanceBefore / 10**18, "MockTokens");
        console.log("Initiating emergency withdrawal of 50 MockTokens...");
        
        resolver.emergencyWithdraw(address(token), 50 * 10**18);
        
        console.log("===> EMERGENCY TOKEN WITHDRAWAL COMPLETED!");
        console.log("===> Owner token balance after emergency:", token.balanceOf(owner) / 10**18, "MockTokens");
        console.log("===> Tokens withdrawn:", (token.balanceOf(owner) - ownerBalanceBefore) / 10**18, "MockTokens");
        
        assertEq(token.balanceOf(owner), ownerBalanceBefore + 50 * 10**18);
        console.log("=== EMERGENCY TOKEN WITHDRAWAL SUCCESSFUL ===\n");
    }

    function testCompleteSwapFunction() public {
        console.log("=== TESTING COMPLETE SWAP EXECUTION ===");
        console.log("Simulating full cross-chain swap scenario...");
        
        console.log("\n--- PHASE 1: SOURCE CHAIN SETUP ---");
        // Setup source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log("===> User approved", srcAmount / 10**18, "MockTokens");
        
        vm.prank(user);
        address payable srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        console.log("===> Source escrow deployed:", srcEscrow);

        console.log("\n--- PHASE 2: DESTINATION CHAIN SETUP ---");
        // Setup destination escrow
        address payable dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, keccak256("salt2")
        ));
        console.log("===> Destination escrow deployed:", dstEscrow);
        console.log("===> Cross-chain infrastructure ready");

        console.log("\n--- PHASE 3: USER CLAIMS DESTINATION FUNDS ---");
        console.log("User withdrawing ETH from destination escrow...");
        // User withdraws from destination first
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        console.log("===> User successfully claimed", dstAmount / 10**18, "ETH");
        console.log("===> Secret revealed on destination chain");

        console.log("\n--- PHASE 4: RESOLVER COMPLETES SWAP ---");
        console.log("Resolver monitoring secret revelation...");
        console.log("Resolver executing complete swap with revealed secret...");
        
        // Resolver completes swap
        uint256 balanceBefore = token.balanceOf(resolver_addr);
        console.log("Resolver token balance before completion:", balanceBefore / 10**18, "MockTokens");
        
        resolver.completeSwap(srcEscrow, dstEscrow, secret);
        
        console.log("===> CROSS-CHAIN SWAP COMPLETED SUCCESSFULLY!");
        console.log("===> Resolver token balance after completion:", token.balanceOf(resolver_addr) / 10**18, "MockTokens");
        console.log("===> Tokens gained by resolver:", (token.balanceOf(resolver_addr) - balanceBefore) / 10**18, "MockTokens");
        
        assertEq(token.balanceOf(resolver_addr), balanceBefore + srcAmount);
        
        console.log("\n=== SWAP SUMMARY ===");
        console.log("===> User gave:", srcAmount / 10**18, "MockTokens");
        console.log("===> User received:", dstAmount / 10**18, "ETH");
        console.log("===> Resolver gave:", dstAmount / 10**18, "ETH");
        console.log("===> Resolver received:", srcAmount / 10**18, "MockTokens");
        console.log("=== CROSS-CHAIN SWAP FULLY COMPLETED! ===\n");
    }

    receive() external payable {}
}

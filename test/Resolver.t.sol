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

    // Shared escrow addresses for ordered tests
    address payable public srcEscrow;
    address payable public dstEscrow;

    uint256 public srcAmount = 1000 * 10**18; // 1000 tokens
    uint256 public dstAmount = 2 ether; // 2 ETH
    uint256 public safetyDeposit = 0.1 ether; // 0.1 ETH safety deposit

    bytes32 public secret = keccak256("secret123");
    bytes32 public secretHash = sha256(abi.encodePacked(secret));
    uint256 public timeout = 1000 + block.timestamp;
    bytes32 public salt = keccak256("salt123");

    function setUp() public {
        console.log("=== CROSS-CHAIN SWAP SYSTEM INITIALIZATION ===");
        console.log("Deploying EscrowFactory contract...");
        
        // Deploy contracts
        factory = new EscrowFactory();
        console.log("==> EscrowFactory deployed at:", address(factory));
        
        console.log("Deploying Resolver contract...");
        resolver = new Resolver(factory, owner);
        resolver_addr = address(resolver);
        console.log("==> Resolver deployed at:", resolver_addr);
        console.log("==> Resolver owner set to:", owner);
        
        console.log("Deploying Mock ERC20 token...");
        token = new MockERC20();
        console.log("==> MockToken deployed at:", address(token));
        console.log("==> Token name:", token.name());
        console.log("==> Token symbol:", token.symbol());

        // Fund accounts (only once in setUp)
        console.log("\n--- INITIAL ACCOUNT FUNDING ---");
        vm.deal(user, 10 ether);
        vm.deal(resolver_addr, 10 ether);
        vm.deal(address(this), 10 ether);
        
        token.transfer(user, 5000 * 10**18);
        token.transfer(resolver_addr, 5000 * 10**18);
        
        console.log("==> All accounts funded with ETH and tokens");
        console.log("=== SYSTEM READY FOR CROSS-CHAIN SWAPS ===\n");
    }

    // TEST 1: Swap Initiation & Order Placement
    function test01_SwapInitiationAndOrderPlacement() public {
        console.log("===  STEP 1: SWAP INITIATION & ORDER PLACEMENT ===");
        console.log("X Cross-chain swap requested:");
        console.log("   * User wants to swap:", srcAmount / 10**18, "MockTokens");
        console.log("   * User wants to receive:", dstAmount / 10**18, "ETH");
        console.log("   * User address:", user);
        console.log("   * Resolver address:", resolver_addr);
        console.log("   * Safety deposit:", safetyDeposit / 10**18, "ETH");
        
        console.log("\n OO Order parameters generated:");
        console.log("   * Secret hash:", vm.toString(secretHash));
        console.log("   * Timeout:", timeout);
        console.log("   * Salt:", vm.toString(salt));
        
        // Verify initial balances
        console.log("\n [v] Initial balances verified:");
        console.log("   * User MockTokens:", token.balanceOf(user) / 10**18);
        console.log("   * User ETH:", user.balance / 10**18);
        console.log("   * Resolver MockTokens:", token.balanceOf(resolver_addr) / 10**18);
        console.log("   * Resolver ETH:", resolver_addr.balance / 10**18);
        
        assertTrue(token.balanceOf(user) >= srcAmount, "User has insufficient tokens");
        assertTrue(resolver_addr.balance >= dstAmount + safetyDeposit, "Resolver has insufficient ETH");
        
        console.log("$$$ SWAP ORDER PLACED SUCCESSFULLY - Ready for escrow deployment");
        console.log("=== END STEP 1 ===\n");
    }

    // TEST 2: Source Escrow Deployment
    function test02_SourceEscrowDeployment() public {
        console.log("=== | | STEP 2: SOURCE ESCROW DEPLOYMENT ===");
        console.log("==> Deploying source escrow on source chain...");
        
        console.log("\n // Source escrow parameters:");
        console.log("   * Maker (User):", user);
        console.log("   * Taker (Resolver):", resolver_addr);
        console.log("   * Token:", address(token));
        console.log("   * Amount:", srcAmount / 10**18, "MockTokens");
        console.log("   * Safety Deposit:", safetyDeposit / 10**18, "ETH");
        
        console.log("\n ==== User approving tokens for EscrowFactory...");
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log("==> Token approval completed");
        console.log("==> Approved amount:", token.allowance(user, address(factory)) / 10**18, "MockTokens");

        console.log("\n ==== Deploying source escrow...");
        vm.prank(user);
        srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, // maker
            secretHash,
            timeout,
            address(token), // ERC20 token
            srcAmount,
            safetyDeposit,
            salt
        ));
        
        console.log(" $$$ SOURCE ESCROW DEPLOYED SUCCESSFULLY!");
        console.log(" == Source escrow address:", srcEscrow);
        console.log("== Escrow token balance:", token.balanceOf(srcEscrow) / 10**18, "MockTokens");
        console.log("== Escrow ETH balance:", srcEscrow.balance / 10**18, "ETH (Safety Deposit)");

        // Verify source escrow was funded correctly
        assertEq(token.balanceOf(srcEscrow), srcAmount);
        assertEq(srcEscrow.balance, safetyDeposit);
        
        console.log(" $$$ Source escrow funding verification PASSED");
        console.log("=== END STEP 2 ===\n");
    }

    // TEST 3: Destination Escrow Deployment
    function test03_DestinationEscrowDeployment() public {
        console.log("===  | | STEP 3: DESTINATION ESCROW DEPLOYMENT ===");
        console.log(" Deploying destination escrow on destination chain...");
        
        console.log("\n Destination escrow parameters:");
        console.log("   * Maker (Resolver):", resolver_addr);
        console.log("   * Taker (User):", user);
        console.log("   * Token: Native ETH (address(0))");
        console.log("   * Amount:", dstAmount / 10**18, "ETH");
        console.log("   * Safety Deposit:", safetyDeposit / 10**18, "ETH");

        console.log("\n Deploying destination escrow...");
        dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, // taker
            secretHash, // same secret hash
            timeout,
            address(0), // native ETH
            dstAmount,
            safetyDeposit,
            salt
        ));

        console.log(" DESTINATION ESCROW DEPLOYED SUCCESSFULLY!");
        console.log(" Destination escrow address:", dstEscrow);
        console.log(" Escrow ETH balance:", dstEscrow.balance / 10**18, "ETH (Amount + Safety Deposit)");
        
        // Verify destination escrow was funded correctly
        assertEq(dstEscrow.balance, dstAmount + safetyDeposit);
        
        console.log(" Destination escrow funding verification PASSED");
        console.log(" CROSS-CHAIN ESCROW INFRASTRUCTURE READY");
        console.log("=== END STEP 3 ===\n");
    }

    // TEST 4: User Claims Destination Funds (Reveals Secret)
    function test04_UserClaimsDestinationFunds() public {
        // Setup escrows first (using previous test logic)
        _setupEscrows();
        
        console.log("===  STEP 4: USER CLAIMS DESTINATION FUNDS ===");
        console.log(" User ready to claim ETH from destination escrow...");
        
        console.log("\n User balances before claiming:");
        uint256 userEthBalanceBefore = user.balance;
        console.log("   * User ETH balance:", userEthBalanceBefore / 10**18, "ETH");
        
        console.log("\n User withdrawing ETH using secret...");
        console.log("   * Secret being revealed:", vm.toString(secret));
        console.log("   * Destination escrow address:", dstEscrow);
        
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        
        console.log(" USER SUCCESSFULLY CLAIMED DESTINATION FUNDS!");
        console.log(" User ETH balance after:", user.balance / 10**18, "ETH");
        console.log(" ETH received by user:", (user.balance - userEthBalanceBefore) / 10**18, "ETH");
        console.log(" SECRET REVEALED ON-CHAIN - Resolver can now complete swap");

        // Verify user received ETH
        assertEq(user.balance, userEthBalanceBefore + dstAmount);
        
        console.log("=== END STEP 4 ===\n");
    }

    // TEST 5: Resolver Completes Swap
    function test05_ResolverCompletesSwap() public {
        // Setup escrows and user withdrawal first
        _setupEscrows();
        
        console.log("===  STEP 5: RESOLVER COMPLETES SWAP ===");
        console.log(" Resolver detected secret revelation...");
        console.log(" Resolver completing swap by claiming source funds...");
        
        // User withdraws from destination first (to reveal secret)
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        console.log("==> Secret revealed by user's destination withdrawal");
        
        console.log("\n Resolver balances before completion:");
        uint256 resolverTokenBalanceBefore = token.balanceOf(resolver_addr);
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        console.log("   * Resolver MockTokens:", resolverTokenBalanceBefore / 10**18);
        console.log("   * Resolver ETH:", resolverEthBalanceBefore / 10**18);
        
        console.log("\n Resolver withdrawing from source escrow...");
        console.log("   * Using revealed secret:", vm.toString(secret));
        console.log("   * Source escrow address:", srcEscrow);
        
        resolver.withdrawFromSrc(srcEscrow, secret);
        
        console.log(" RESOLVER SUCCESSFULLY COMPLETED SWAP!");
        console.log(" Resolver MockTokens after:", token.balanceOf(resolver_addr) / 10**18);
        console.log(" Resolver ETH after:", resolver_addr.balance / 10**18);
        console.log(" MockTokens gained:", (token.balanceOf(resolver_addr) - resolverTokenBalanceBefore) / 10**18);
        console.log(" Safety deposit received:", (resolver_addr.balance - resolverEthBalanceBefore) / 10**18, "ETH");

        // Verify resolver received tokens + safety deposit
        assertEq(token.balanceOf(resolver_addr), resolverTokenBalanceBefore + srcAmount);
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + safetyDeposit);
        
        console.log("\n CROSS-CHAIN SWAP COMPLETED SUCCESSFULLY!");
        console.log(" SWAP SUMMARY:");
        console.log(" * User traded:");
        console.log("     - Sent MockTokens: %s", srcAmount / 10**18);
        console.log("     - Received ETH: %s", dstAmount / 10**18);
        console.log("   * Resolver traded:");
        console.log("     ETH sent: %s", dstAmount / 10**18);
        console.log("     MockTokens received: %s", srcAmount / 10**18);
        console.log("=== END STEP 5 ===\n");
    }

    // TEST 6: Timeout Scenario - Source Cancellation
    function test06_TimeoutScenario_SourceCancellation() public {
        console.log("===  STEP 6: TIMEOUT SCENARIO - SOURCE CANCELLATION ===");
        console.log(" Testing timeout and cancellation mechanism...");
        
        // Setup source escrow only
        console.log("\n Setting up source escrow for timeout test...");
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        address payable timeoutSrcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, keccak256("timeout_salt")
        ));
        console.log("==> Source escrow created for timeout test:", timeoutSrcEscrow);

        console.log("\n Simulating swap timeout...");
        console.log("   * Current timestamp:", block.timestamp);
        console.log("   * Timeout set for:", timeout);
        console.log("   * No activity on destination chain detected...");
        
        vm.warp(timeout + 1);
        console.log("==> Time warped past timeout");
        console.log("   * New timestamp:", block.timestamp);
        console.log("  TIMEOUT EXCEEDED - Cancellation available");

        console.log("\n Initiating cancellation process...");
        uint256 userTokenBalanceBefore = token.balanceOf(user);
        uint256 userEthBalanceBefore = user.balance;
        
        resolver.cancelSrc(timeoutSrcEscrow);
        
        console.log(" SOURCE ESCROW CANCELLED SUCCESSFULLY!");
        console.log(" User tokens refunded:", (token.balanceOf(user) - userTokenBalanceBefore) / 10**18);
        console.log(" User safety deposit refunded:", (user.balance - userEthBalanceBefore) / 10**18, "ETH");

        assertEq(token.balanceOf(user), userTokenBalanceBefore + srcAmount);
        assertEq(user.balance, userEthBalanceBefore + safetyDeposit);
        
        console.log("=== END STEP 6 ===\n");
    }

    // TEST 7: Emergency Functions
    function test07_EmergencyFunctions() public {
        console.log("===  STEP 7: EMERGENCY FUNCTIONS TEST ===");
        console.log(" Testing emergency withdrawal capabilities...");
        
        console.log("\n Testing emergency ETH withdrawal...");
        uint256 balBefore = address(owner).balance;
        console.log("   * Owner ETH before:", balBefore / 10**18, "ETH");
        
        resolver.emergencyWithdraw(address(0), 1 ether);
        console.log(" Emergency ETH withdrawal completed");
        console.log("   * Owner ETH after:", address(owner).balance / 10**18, "ETH");
        
        console.log("\n Testing emergency token withdrawal...");
        token.transfer(resolver_addr, 100 * 10**18);
        uint256 ownerTokensBefore = token.balanceOf(owner);
        
        resolver.emergencyWithdraw(address(token), 50 * 10**18);
        console.log(" Emergency token withdrawal completed");
        console.log("   * Tokens withdrawn:", (token.balanceOf(owner) - ownerTokensBefore) / 10**18);
        
        assertEq(address(owner).balance, balBefore + 1 ether);
        assertEq(token.balanceOf(owner), ownerTokensBefore + 50 * 10**18);
        
        console.log("=== END STEP 7 ===\n");
    }

    // TEST 8: Utility Functions
    function test08_UtilityFunctions() public {
        console.log("===  STEP 8: UTILITY FUNCTIONS TEST ===");
        console.log(" Testing helper and utility functions...");
        
        console.log("\n Testing secret verification...");
        bool isValid = resolver.verifySecret(secret, secretHash);
        bool isInvalid = resolver.verifySecret(keccak256("wrong"), secretHash);
        
        console.log("   * Correct secret verification:", isValid);
        console.log("   * Wrong secret verification:", isInvalid);
        
        assertTrue(isValid);
        assertFalse(isInvalid);
        
        console.log("\n Testing timeout check functions...");
        _setupEscrows();
        
        bool timeoutBefore = resolver.isTimeoutPassed(srcEscrow);
        vm.warp(timeout + 1);
        bool timeoutAfter = resolver.isTimeoutPassed(srcEscrow);
        
        console.log("   * Timeout before expiry:", timeoutBefore);
        console.log("   * Timeout after expiry:", timeoutAfter);
        
        assertFalse(timeoutBefore);
        assertTrue(timeoutAfter);
        
        console.log(" All utility functions working correctly");
        console.log("=== END STEP 8 ===\n");
    }

    // Helper function to setup escrows (used by multiple tests)
    function _setupEscrows() internal {
        // Setup source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        
        vm.prank(user);
        srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));
        
        // Setup destination escrow
        dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, salt
        ));
    }

    receive() external payable {}
}

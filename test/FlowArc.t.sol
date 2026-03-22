// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/FlowArc.sol";

// ─── Mock USDC Token ───────────────────────────────────────────────────────────
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name     = "USD Coin";
    string public symbol   = "USDC";
    uint8  public decimals = 6;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to]         += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from]             -= amount;
        balanceOf[to]               += amount;
        return true;
    }
}

// ─── FlowArc Tests ─────────────────────────────────────────────────────────────
contract FlowArcTest is Test {
    FlowArc   flowarc;
    MockUSDC  usdc;

    address employer = address(0x1);
    address worker1  = address(0x2);
    address worker2  = address(0x3);

    uint256 constant MONTHLY_SALARY = 1000e6; // 1000 USDC
    uint256 constant DEPOSIT_AMOUNT = 5000e6; // 5000 USDC

    function setUp() public {
        usdc     = new MockUSDC();
        flowarc  = new FlowArc(address(usdc));

        // Fund employer with USDC
        usdc.mint(employer, 10_000e6);

        // Approve FlowArc to spend employer USDC
        vm.prank(employer);
        usdc.approve(address(flowarc), type(uint256).max);
    }

    // ─── Employer Tests ────────────────────────────────────────────────

    function testRegisterEmployer() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        (string memory name,,bool registered) = flowarc.employers(employer);
        assertEq(name, "FlowArc Inc");
        assertTrue(registered);
    }

    function testCannotRegisterTwice() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        vm.expectRevert("Already registered");
        flowarc.registerEmployer("FlowArc Inc");
    }

    function testDepositFunds() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.depositFunds(DEPOSIT_AMOUNT);

        (, uint256 balance,) = flowarc.employers(employer);
        assertEq(balance, DEPOSIT_AMOUNT);
    }

    function testWithdrawFunds() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.depositFunds(DEPOSIT_AMOUNT);

        vm.prank(employer);
        flowarc.withdrawFunds(1000e6);

        (, uint256 balance,) = flowarc.employers(employer);
        assertEq(balance, DEPOSIT_AMOUNT - 1000e6);
    }

    // ─── Worker Tests ──────────────────────────────────────────────────

    function testAddWorker() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.addWorker(worker1, "Alice", MONTHLY_SALARY);

        (string memory name,,,,bool active,) = flowarc.getWorkerDetails(employer, worker1);
        assertEq(name, "Alice");
        assertTrue(active);
    }

    function testRemoveWorker() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.addWorker(worker1, "Alice", MONTHLY_SALARY);

        vm.prank(employer);
        flowarc.removeWorker(worker1);

        (,,,,bool active,) = flowarc.getWorkerDetails(employer, worker1);
        assertFalse(active);
    }

    // ─── Salary Claim Tests ────────────────────────────────────────────

    function testClaimSalaryAfter30Days() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.depositFunds(DEPOSIT_AMOUNT);

        vm.prank(employer);
        flowarc.addWorker(worker1, "Alice", MONTHLY_SALARY);

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        uint256 earned = flowarc.getEarnedAmount(employer, worker1);
        assertApproxEqAbs(earned, MONTHLY_SALARY, 3e6); // within 0.01 USDC tolerance

        vm.prank(worker1);
        flowarc.claimSalary(employer);

        assertEq(usdc.balanceOf(worker1), earned);
    }

    function testCannotClaimWithInsufficientEmployerFunds() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        // Deposit very little
        vm.prank(employer);
        flowarc.depositFunds(1e6); // only 1 USDC

        vm.prank(employer);
        flowarc.addWorker(worker1, "Alice", MONTHLY_SALARY);

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        vm.prank(worker1);
        vm.expectRevert("Employer has insufficient funds");
        flowarc.claimSalary(employer);
    }

    function testMultipleWorkersClaim() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.depositFunds(DEPOSIT_AMOUNT);

        vm.prank(employer);
        flowarc.addWorker(worker1, "Alice", MONTHLY_SALARY);

        vm.prank(employer);
        flowarc.addWorker(worker2, "Bob", MONTHLY_SALARY);

        // Fast forward 15 days
        vm.warp(block.timestamp + 15 days);

        vm.prank(worker1);
        flowarc.claimSalary(employer);

        vm.prank(worker2);
        flowarc.claimSalary(employer);

        // Both should have roughly half monthly salary
        assertApproxEqAbs(usdc.balanceOf(worker1), MONTHLY_SALARY / 2, 2e6);
        assertApproxEqAbs(usdc.balanceOf(worker2), MONTHLY_SALARY / 2, 2e6);
    }

    function testGetEmployerWorkers() public {
        vm.prank(employer);
        flowarc.registerEmployer("FlowArc Inc");

        vm.prank(employer);
        flowarc.addWorker(worker1, "Alice", MONTHLY_SALARY);

        vm.prank(employer);
        flowarc.addWorker(worker2, "Bob", MONTHLY_SALARY);

        address[] memory workerList = flowarc.getEmployerWorkers(employer);
        assertEq(workerList.length, 2);
        assertEq(workerList[0], worker1);
        assertEq(workerList[1], worker2);
    }
}

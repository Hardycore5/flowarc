// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IPayslipNFT {
    function mintPayslip(
        address employer,
        address worker,
        uint256 amount,
        string calldata companyName
    ) external returns (uint256);
}

contract FlowArc {
    // ─── State Variables ───────────────────────────────────────────────
    IERC20      public immutable usdc;
    IPayslipNFT public payslipNFT;
    address     public owner;

    struct Worker {
        string  name;
        uint256 salaryPerSecond;
        uint256 lastClaimed;
        uint256 startTime;
        bool    active;
    }

    struct Employer {
        string  companyName;
        uint256 balance;
        bool    registered;
    }

    mapping(address => Employer)                   public employers;
    mapping(address => mapping(address => Worker)) public workers;
    mapping(address => address[])                  public employerWorkers;

    // ─── Events ────────────────────────────────────────────────────────
    event EmployerRegistered(address indexed employer, string companyName);
    event WorkerAdded(address indexed employer, address indexed worker, string name, uint256 salaryPerSecond);
    event WorkerRemoved(address indexed employer, address indexed worker);
    event FundsDeposited(address indexed employer, uint256 amount);
    event FundsWithdrawn(address indexed employer, uint256 amount);
    event SalaryClaimed(address indexed employer, address indexed worker, uint256 amount, uint256 payslipTokenId);
    event PayslipNFTSet(address indexed payslipNFT);

    // ─── Modifiers ─────────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyRegisteredEmployer() {
        require(employers[msg.sender].registered, "Not a registered employer");
        _;
    }

    modifier onlyActiveWorker(address employer) {
        require(workers[employer][msg.sender].active, "Not an active worker");
        _;
    }

    // ─── Constructor ───────────────────────────────────────────────────
    constructor(address _usdc) {
        usdc  = IERC20(_usdc);
        owner = msg.sender;
    }

    // ─── Admin Functions ───────────────────────────────────────────────
    function setPayslipNFT(address _payslipNFT) external onlyOwner {
        payslipNFT = IPayslipNFT(_payslipNFT);
        emit PayslipNFTSet(_payslipNFT);
    }

    // ─── Employer Functions ────────────────────────────────────────────
    function registerEmployer(string calldata companyName) external {
        require(!employers[msg.sender].registered, "Already registered");
        employers[msg.sender] = Employer({
            companyName: companyName,
            balance:     0,
            registered:  true
        });
        emit EmployerRegistered(msg.sender, companyName);
    }

    function depositFunds(uint256 amount) external onlyRegisteredEmployer {
        require(amount > 0, "Amount must be greater than 0");
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        employers[msg.sender].balance += amount;
        emit FundsDeposited(msg.sender, amount);
    }

    function withdrawFunds(uint256 amount) external onlyRegisteredEmployer {
        require(employers[msg.sender].balance >= amount, "Insufficient balance");
        employers[msg.sender].balance -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit FundsWithdrawn(msg.sender, amount);
    }

    function addWorker(
        address workerAddress,
        string  calldata name,
        uint256 monthlySalary
    ) external onlyRegisteredEmployer {
        require(!workers[msg.sender][workerAddress].active, "Worker already active");
        require(workerAddress != address(0), "Invalid worker address");

        uint256 salaryPerSecond = monthlySalary / (30 days);

        workers[msg.sender][workerAddress] = Worker({
            name:            name,
            salaryPerSecond: salaryPerSecond,
            lastClaimed:     block.timestamp,
            startTime:       block.timestamp,
            active:          true
        });

        employerWorkers[msg.sender].push(workerAddress);
        emit WorkerAdded(msg.sender, workerAddress, name, salaryPerSecond);
    }

    function removeWorker(address workerAddress) external onlyRegisteredEmployer {
        require(workers[msg.sender][workerAddress].active, "Worker not active");
        workers[msg.sender][workerAddress].active = false;
        emit WorkerRemoved(msg.sender, workerAddress);
    }

    // ─── Worker Functions ──────────────────────────────────────────────
    function claimSalary(address employer) external onlyActiveWorker(employer) {
        Worker storage worker  = workers[employer][msg.sender];
        uint256 earned         = getEarnedAmount(employer, msg.sender);
        require(earned > 0, "Nothing to claim");
        require(employers[employer].balance >= earned, "Employer has insufficient funds");

        worker.lastClaimed          = block.timestamp;
        employers[employer].balance -= earned;

        require(usdc.transfer(msg.sender, earned), "Transfer failed");

        // Mint payslip NFT if PayslipNFT contract is set
        uint256 tokenId = 0;
        if (address(payslipNFT) != address(0)) {
            tokenId = payslipNFT.mintPayslip(
                employer,
                msg.sender,
                earned,
                employers[employer].companyName
            );
        }

        emit SalaryClaimed(employer, msg.sender, earned, tokenId);
    }

    // ─── View Functions ────────────────────────────────────────────────
    function getEarnedAmount(address employer, address workerAddress) public view returns (uint256) {
        Worker memory worker = workers[employer][workerAddress];
        if (!worker.active) return 0;
        uint256 elapsed = block.timestamp - worker.lastClaimed;
        return elapsed * worker.salaryPerSecond;
    }

    function getEmployerWorkers(address employer) external view returns (address[] memory) {
        return employerWorkers[employer];
    }

    function getWorkerDetails(address employer, address workerAddress) external view returns (
        string memory name,
        uint256 salaryPerSecond,
        uint256 lastClaimed,
        uint256 startTime,
        bool active,
        uint256 earned
    ) {
        Worker memory w = workers[employer][workerAddress];
        return (
            w.name,
            w.salaryPerSecond,
            w.lastClaimed,
            w.startTime,
            w.active,
            getEarnedAmount(employer, workerAddress)
        );
    }
}

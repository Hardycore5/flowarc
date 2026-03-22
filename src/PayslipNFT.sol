// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract PayslipNFT {

    // ─── State Variables ───────────────────────────────────────────────
    string  public name     = "FlowArc Payslip";
    string  public symbol   = "FPAY";
    address public flowArc;
    uint256 private _tokenIdCounter;

    struct Payslip {
        address employer;
        address worker;
        uint256 amount;
        uint256 timestamp;
        string  companyName;
    }

    mapping(uint256 => Payslip)  public payslips;       // tokenId => Payslip
    mapping(uint256 => address)  public ownerOf;        // tokenId => owner
    mapping(address => uint256)  public balanceOf;      // worker => token count
    mapping(address => uint256[]) public workerPayslips; // worker => tokenIds

    // ─── Events ────────────────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event PayslipMinted(address indexed worker, uint256 indexed tokenId, uint256 amount);

    // ─── Modifiers ─────────────────────────────────────────────────────
    modifier onlyFlowArc() {
        require(msg.sender == flowArc, "Only FlowArc contract can mint");
        _;
    }

    // ─── Constructor ───────────────────────────────────────────────────
    constructor(address _flowArc) {
        flowArc = _flowArc;
    }

    // ─── Mint Function (called by FlowArc on every salary claim) ───────
    function mintPayslip(
        address employer,
        address worker,
        uint256 amount,
        string calldata companyName
    ) external onlyFlowArc returns (uint256) {
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;

        ownerOf[tokenId]  = worker;
        balanceOf[worker] += 1;

        payslips[tokenId] = Payslip({
            employer:    employer,
            worker:      worker,
            amount:      amount,
            timestamp:   block.timestamp,
            companyName: companyName
        });

        workerPayslips[worker].push(tokenId);

        emit Transfer(address(0), worker, tokenId);
        emit PayslipMinted(worker, tokenId, amount);

        return tokenId;
    }

    // ─── Soulbound: Block all transfers ────────────────────────────────
    function transferFrom(address, address, uint256) external pure {
        revert("Payslips are non-transferable");
    }

    function approve(address, uint256) external pure {
        revert("Payslips are non-transferable");
    }

    // ─── View Functions ────────────────────────────────────────────────
    function getPayslip(uint256 tokenId) external view returns (
        address employer,
        address worker,
        uint256 amount,
        uint256 timestamp,
        string memory companyName
    ) {
        Payslip memory p = payslips[tokenId];
        return (p.employer, p.worker, p.amount, p.timestamp, p.companyName);
    }

    function getWorkerPayslips(address worker) external view returns (uint256[] memory) {
        return workerPayslips[worker];
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}

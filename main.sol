// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MaintMaster — Orchestration layer for distributed AI maintenance and diagnostic cycles
/// @notice Schedules maintenance windows, records health scores, and logs repair tickets across registered nodes.
///         Uses a single controller and optional operators; all configuration is fixed at deployment.
/// @custom:inspiration Industrial SCADA maintenance cycles and predictive health thresholds.
contract MaintMaster {
    // ─── Immutable authority and config ──────────────────────────────────────────
    address public immutable controller;
    address public immutable operatorA;
    address public immutable operatorB;
    address public immutable auditSink;
    address public immutable escalationTarget;

    uint256 public immutable deployBlock;
    uint256 public immutable minHealthScoreBps;
    uint256 public immutable maxMaintenanceDurationBlocks;
    uint256 public immutable diagnosticCooldownBlocks;
    uint256 public immutable maxNodes;
    uint256 public immutable maxRepairTicketsPerNode;
    bytes32 public immutable configNonce;

    // ─── Constants (unique naming) ──────────────────────────────────────────────
    uint256 public constant HEALTH_BASIS_POINTS = 10_000;
    uint256 public constant MAINT_WINDOW_GRACE_BLOCKS = 12;
    uint256 public constant REPAIR_SEVERITY_MIN = 1;
    uint256 public constant REPAIR_SEVERITY_MAX = 5;
    uint256 public constant DIAGNOSTIC_RESULT_CAP = 1e18;
    uint256 public constant DEFAULT_HEALTH_BPS_UNTIL_FIRST_RUN = 10_000;
    uint256 public constant OPEN_TICKET_SEVERITY_CRITICAL = 5;

    // ─── State ──────────────────────────────────────────────────────────────────
    uint256 private _reentrancyLock;
    uint256 public nextNodeId;
    uint256 public nextMaintenanceWindowId;
    uint256 public nextDiagnosticRunId;
    uint256 public nextRepairTicketId;
    uint256 public totalDiagnosticRuns;
    uint256 public totalRepairTicketsResolved;

    mapping(uint256 => NodeRecord) private _nodes;
    mapping(uint256 => MaintenanceWindow) private _maintenanceWindows;
    mapping(uint256 => DiagnosticRun) private _diagnosticRuns;
    mapping(uint256 => RepairTicket) private _repairTickets;
    mapping(uint256 => uint256[]) private _ticketIdsByNode;
    mapping(address => uint256) public nodeIdByAddress;
    mapping(uint256 => uint256) public lastDiagnosticBlockByNode;
    mapping(uint256 => uint256) public healthScoreBpsByNode;

    struct NodeRecord {
        bytes32 label;
        address nodeAddress;
        bool active;
        uint256 registeredAtBlock;
        uint256 totalDiagnostics;
        uint256 totalRepairsResolved;
    }

    struct MaintenanceWindow {
        uint256 nodeId;
        uint256 startBlock;
        uint256 endBlock;
        bytes32 reasonHash;

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract L2Mixer {
    struct Deposit {
        address depositor;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(bytes32 => Deposit[]) public deposits;
    mapping(address => bool) public participants;
    address[] public participantList;
    uint256 public numParticipants;
    uint256 public numDeposits;
    uint256 public depositFee;
    uint256 public constant MIX_SIZE = 5;
    uint256 public constant INTEREST_RATE = 5; // 5% annual interest rate
    uint256 public constant FEE_RATE = 1; // 1% fee rate on withdrawals

    event DepositMade(address indexed depositor, uint256 amount);
    event WithdrawalMade(address indexed recipient, uint256 amount);
    event FeeUpdated(uint256 newFee);

    constructor(uint256 _depositFee) {
        depositFee = _depositFee;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        require(msg.value % MIX_SIZE == 0, "Deposit amount must be divisible by mix size");

        uint256 fee = (msg.value * depositFee) / 100;
        uint256 amountAfterFee = msg.value - fee;

        deposits[keccak256(abi.encodePacked(block.timestamp, msg.sender))].push(Deposit(msg.sender, amountAfterFee, block.timestamp));
        numDeposits++;
        emit DepositMade(msg.sender, amountAfterFee);
    }

    function withdraw(bytes32[] calldata _depositIds) external {
        require(_depositIds.length == MIX_SIZE, "Invalid number of deposits");

        uint256 totalAmount;
        address[] memory depositors = new address[](MIX_SIZE);
        for (uint256 i = 0; i < MIX_SIZE; i++) {
            require(deposits[_depositIds[i]].length > 0, "Deposit not found");
            require(!participants[deposits[_depositIds[i]][0].depositor], "Deposit already used");
            depositors[i] = deposits[_depositIds[i]][0].depositor;
            totalAmount += deposits[_depositIds[i]][0].amount;
            delete deposits[_depositIds[i]][0];
        }

        address payable recipient = payable(msg.sender);
        uint256 fee = (totalAmount * FEE_RATE) / 100;
        uint256 amountAfterFee = totalAmount - fee;
        recipient.transfer(amountAfterFee);
        emit WithdrawalMade(recipient, amountAfterFee);

        uint256 interest = (amountAfterFee * INTEREST_RATE) / 100;
        payable(address(this)).transfer(interest);

        for (uint256 i = 0; i < MIX_SIZE; i++) {
            participants[depositors[i]] = true;
        }
        numParticipants += MIX_SIZE;
        participantList = depositors;
    }

    function updateFee(uint256 _newFee) external {
        require(_newFee <= 100, "Fee cannot exceed 100%");
        depositFee = _newFee;
        emit FeeUpdated(_newFee);
    }
}

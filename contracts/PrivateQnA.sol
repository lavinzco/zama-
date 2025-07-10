// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FHE, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract PrivateQnA is SepoliaConfig {
    enum DisputeStatus { None, Open, Resolved }

    struct Question {
        address asker;
        string encryptedQuestion;
        bool isAnswered;
        bool isAccepted;
    }

    struct Reply {
        string encryptedReply;
        address replier;
    }

    struct Reward {
        IERC20 token;
        uint256 amount;
        bool claimed;
    }

    struct Dispute {
        address appellant;
        address arbitrator;
        bool rulingForAppellant;
        DisputeStatus status;
    }

    address[] public users;
    mapping(address => bool) public isRegistered;

    mapping(uint => Question) public questions;
    mapping(uint => address) public questionToRecipient;
    mapping(uint => Reply) public replies;
    mapping(uint => mapping(address => bool)) public triedCandidates;
    mapping(uint => Reward) public rewards;
    mapping(uint => Dispute) public disputes;

    uint public questionCounter;

    event QuestionAsked(uint indexed questionId, address indexed asker);
    event QuestionOffered(uint indexed questionId, address indexed candidate);
    event QuestionAccepted(uint indexed questionId, address indexed recipient);
    event QuestionAnswered(uint indexed questionId, address indexed replier);
    event DisputeFiled(uint indexed questionId, address indexed appellant);
    event DisputeResolved(uint indexed questionId, bool ruledForAsker, address indexed arbitrator);

    modifier onlyRegistered() {
        if (!isRegistered[msg.sender]) {
            users.push(msg.sender);
            isRegistered[msg.sender] = true;
        }
        _;
    }

    function askQuestionWithReward(
        string calldata encryptedQuestion,
        IERC20 token,
        uint256 amount
    ) external onlyRegistered {
        require(amount > 0, "Must attach reward");

        uint questionId = questionCounter++;

        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        questions[questionId] = Question({
            asker: msg.sender,
            encryptedQuestion: encryptedQuestion,
            isAnswered: false,
            isAccepted: false
        });

        rewards[questionId] = Reward({
            token: token,
            amount: amount,
            claimed: false
        });

        emit QuestionAsked(questionId, msg.sender);
    }

    function tryDeliverQuestion(uint questionId, externalEuint32 salt, bytes calldata proof) external onlyRegistered {
        require(!questions[questionId].isAccepted, "Already accepted");

        FHE.fromExternal(salt, proof);

        uint seed = uint(keccak256(abi.encodePacked(salt, block.timestamp, msg.sender, questionId)));
        uint len = users.length;
        require(len > 1, "Not enough users");

        for (uint i = 0; i < len; i++) {
            uint index = (seed + i) % len;
            address candidate = users[index];

            if (candidate == questions[questionId].asker) continue;
            if (triedCandidates[questionId][candidate]) continue;

            triedCandidates[questionId][candidate] = true;
            questionToRecipient[questionId] = candidate;

            emit QuestionOffered(questionId, candidate);
            return;
        }

        revert("No available recipient found");
    }

    function acceptQuestion(uint questionId) external {
        require(questionToRecipient[questionId] == msg.sender, "Not the candidate");
        require(!questions[questionId].isAccepted, "Already accepted");

        questions[questionId].isAccepted = true;

        emit QuestionAccepted(questionId, msg.sender);
    }

    function replyToQuestion(uint questionId, string calldata encryptedReply) external {
        require(questionToRecipient[questionId] == msg.sender, "Not authorized to reply");
        require(questions[questionId].isAccepted, "Question not accepted yet");
        require(!questions[questionId].isAnswered, "Already answered");

        questions[questionId].isAnswered = true;
        replies[questionId] = Reply({
            encryptedReply: encryptedReply,
            replier: msg.sender
        });

        emit QuestionAnswered(questionId, msg.sender);

        Reward storage reward = rewards[questionId];
        if (!reward.claimed && reward.amount > 0) {
            reward.claimed = true;
            require(reward.token.transfer(msg.sender, reward.amount), "Reward transfer failed");
        }
    }

    function fileDispute(uint questionId) external {
        Question storage q = questions[questionId];
        require(msg.sender == q.asker, "Only asker can appeal");
        require(q.isAnswered, "Cannot appeal unanswered question");
        require(disputes[questionId].status == DisputeStatus.None, "Already disputed");

        disputes[questionId] = Dispute({
            appellant: msg.sender,
            arbitrator: address(0),
            rulingForAppellant: false,
            status: DisputeStatus.Open
        });

        emit DisputeFiled(questionId, msg.sender);
    }

    function arbitrateDispute(uint questionId, bool ruleInFavorOfAsker) external onlyRegistered {
        Dispute storage d = disputes[questionId];
        Reward storage r = rewards[questionId];
        Question storage q = questions[questionId];

        require(d.status == DisputeStatus.Open, "Not disputable");
        require(msg.sender != q.asker && msg.sender != replies[questionId].replier, "Not neutral");

        d.arbitrator = msg.sender;
        d.rulingForAppellant = ruleInFavorOfAsker;
        d.status = DisputeStatus.Resolved;

        require(!r.claimed, "Reward already handled");
        r.claimed = true;

        uint256 tenPercent = (r.amount * 10) / 100;
        uint256 ninetyPercent = r.amount - tenPercent;

        if (ruleInFavorOfAsker) {
            require(r.token.transfer(q.asker, ninetyPercent), "Refund to asker failed");
        } else {
            require(r.token.transfer(replies[questionId].replier, ninetyPercent), "Transfer to replier failed");
        }

        require(r.token.transfer(msg.sender, tenPercent), "Transfer to arbitrator failed");

        emit DisputeResolved(questionId, ruleInFavorOfAsker, msg.sender);
    }

    function getEncryptedReply(uint questionId) external view returns (string memory) {
        require(msg.sender == questions[questionId].asker, "Only asker can see reply");
        return replies[questionId].encryptedReply;
    }

    function getAllUsers() external view returns (address[] memory) {
        return users;
    }
}


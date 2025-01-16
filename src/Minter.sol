// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Broker, LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Minter is ERC721, Ownable, ReentrancyGuardTransient {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    ISablierV2LockupLinear public immutable sablier;

    enum Phase {
        PAUSED,
        PHASE1,
        PHASE2,
        PUBLIC,
        END
    }

    uint256 counter;
    bytes32 public merkleRoot;
    uint256 public immutable mintFee;
    IERC20 public feeToken;
    Phase public currentPhase = Phase.PAUSED;

    mapping(address => bool) public claimed;

    event Mint(address indexed from, uint256 indexed tokenId);
    event Vesting(address sender, address recipient, uint256 streamId);
    event Withdraw(address recipient, uint128 amount);

    constructor(
        address verifier,
        bytes32 _merkleRoot,
        IERC20 _feeToken,
        ISablierV2LockupLinear _sablier,
        uint256 _mintFee
    ) ERC721("Insomnia", "ISN") Ownable(verifier) {
        merkleRoot = _merkleRoot;
        feeToken = _feeToken;
        sablier = _sablier;
        mintFee = _mintFee;
    }

    function setPhase(Phase _phase) public onlyOwner {
        currentPhase = _phase;
    }

    function setRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function mint() public {
        require(currentPhase == Phase.PUBLIC, "INSOMNIA: Public phase not active");
        address sender = msg.sender; // variable caching

        if (claimed[sender]) revert("INSOMNIA: Address already claimed");
        claimed[msg.sender] = true;

        feeToken.safeTransferFrom(msg.sender, address(this), mintFee); // Fee transfer

        counter = counter + 1;
        _safeMint(msg.sender, counter);

        emit Mint(msg.sender, counter);
    }

    function mint(bytes32[] calldata phase1Merkleproof) public {
        require(currentPhase == Phase.PHASE1, "INSOMNIA: Phase 1 not active");
        address sender = msg.sender; // variable caching

        if (claimed[sender]) revert("INSOMNIA: Address already claimed");
        claimed[sender] = true;

        bytes32 leaf = keccak256(abi.encodePacked(sender));

        // verify merkle proof
        if (!MerkleProof.verifyCalldata(phase1Merkleproof, merkleRoot, leaf)) {
            revert("INSOMNIA: Invalid proof");
        }

        counter = counter + 1;
        _safeMint(sender, counter);

        emit Mint(sender, counter);
    }

    function mintWithDiscount(bytes calldata signature, bytes32[] calldata phase2Merkleproof) public {
        require(currentPhase == Phase.PHASE2, "INSOMNIA: Phase 2 not active");
        address sender = msg.sender; // variable caching
        uint256 discount = 20;
        bytes32 messageHash = keccak256(abi.encodePacked(sender, phase2Merkleproof, discount)); // Message hash of the claimer and the discount percentage

        if (claimed[sender]) revert("INSOMNIA: Address already claimed");
        claimed[sender] = true;

        bool valid = messageHash.toEthSignedMessageHash().recover(signature) == owner();

        require(valid, "INSOMNIA: Invalid signature");

        bytes32 leaf = keccak256(abi.encodePacked(sender, discount));

        if (!MerkleProof.verifyCalldata(phase2Merkleproof, merkleRoot, leaf)) {
            revert("INSOMNIA: Invalid proof");
        }

        uint256 feeWithDiscount = mintFee - (mintFee * discount / 100);
        feeToken.safeTransferFrom(msg.sender, address(this), feeWithDiscount); // fee transfer

        counter = counter + 1;
        _safeMint(sender, counter);

        emit Mint(sender, counter);
    }

    function toSablier() public onlyOwner nonReentrant returns (uint256 streamId) {
        require(currentPhase == Phase.END, "INSOMNIA: Minting processes still active");
        uint256 totalAmount = feeToken.balanceOf(address(this));
        feeToken.safeIncreaseAllowance(address(sablier), totalAmount); //safeIncreaseAllowance is used to prevent race conditions

        // Declare params struct
        LockupLinear.CreateWithDurations memory params;

        params.sender = address(this);
        params.recipient = owner();
        params.totalAmount = uint128(totalAmount);
        params.asset = feeToken;
        params.cancelable = false;
        params.transferable = true;
        params.durations = LockupLinear.Durations({cliff: 52 weeks, total: 104 weeks});
        params.broker = Broker(address(0), ud60x18(0));

        streamId = sablier.createWithDurations(params);

        emit Vesting(params.sender, params.recipient, streamId);
    }
}

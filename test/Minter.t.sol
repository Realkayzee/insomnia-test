// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseTest} from "./Base.t.sol";
import {Minter} from "../src/Minter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinterTest is BaseTest {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;

    function setUp() public override {
        super.setUp();
    }

    function test_Phase1SuccessfulFreeMintAndEmitCheck() public {
        address user1 = 0x7A1CF8CE543F4838c964FB14D403Cc6ED0bDbaCC;
        string[] memory user1Proof =
            vm.parseJsonStringArray(merkle1Json, ".0x7A1CF8CE543F4838c964FB14D403Cc6ED0bDbaCC.proof");

        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE1);

        vm.stopPrank();

        // User mint
        vm.startPrank(user1);
        bytes32[] memory proof1 = new bytes32[](user1Proof.length);

        for (uint256 i = 0; i < user1Proof.length; i++) {
            proof1[i] = vm.parseBytes32(user1Proof[i]);
        }

        vm.expectEmit(address(minter));
        emit Minter.Mint(user1, 1);

        minter.mint(proof1);

        uint256 balance = minter.balanceOf(user1);
        assert(balance == 1);

        vm.stopPrank();
    }

    function test_RevertWhen_InvalidProof() public {
        address user = 0x6b6481A6Fb950a7c24D6fC79731894553b909743;
        bytes32[] memory proof1 = new bytes32[](4);
        proof1[0] = 0x6207bb34599074ca8e1db49a23287ecf8727a6429429f4084b28815e97919195;
        proof1[1] = 0xb4350eb845d7f6e4e92d62bf03e66f931bee6f4cb5cfe5d4ff529c342c08329f;
        proof1[2] = 0x284a228a7f6b821105b9cf515472f691b1d2a09ec5c0241a17cdb8fa91f442b8;
        proof1[3] = 0xb4350eb845d7f6e4e92d62bf03e66f931bee6f4cb5cfe5d4ff529c342c08329f;

        // Verifying signer setup
        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE1);

        vm.stopPrank();

        // User mint
        vm.startPrank(user);
        vm.expectRevert("INSOMNIA: Invalid proof");
        minter.mint(proof1);

        vm.stopPrank();
    }

    function test_RevertWhen_Phase1ClaimTwice() public {
        address user1 = 0x477b8D5eF7C2C42DB84deB555419cd817c336b6F;
        string[] memory user1Proof =
            vm.parseJsonStringArray(merkle1Json, ".0x477b8D5eF7C2C42DB84deB555419cd817c336b6F.proof");

        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE1);

        vm.stopPrank();

        // User mint
        vm.startPrank(user1);
        bytes32[] memory proof1 = new bytes32[](user1Proof.length);

        for (uint256 i = 0; i < user1Proof.length; i++) {
            proof1[i] = vm.parseBytes32(user1Proof[i]);
        }

        // First claim
        minter.mint(proof1);

        // Second claim
        vm.expectRevert("INSOMNIA: Address already claimed");
        minter.mint(proof1);

        uint256 balance = minter.balanceOf(user1);
        assert(balance == 1);

        vm.stopPrank();
    }

    function test_RevertWhen_PhaseNotActive() public {
        address user1 = 0xF6D4E5a7c5215F91f59a95065190CCa24bf64554;
        string[] memory userProof =
            vm.parseJsonStringArray(merkle1Json, ".0xF6D4E5a7c5215F91f59a95065190CCa24bf64554.proof");

        // User mint
        vm.startPrank(user1);
        bytes32[] memory proof = new bytes32[](userProof.length);

        for (uint256 i = 0; i < userProof.length; i++) {
            proof[i] = vm.parseBytes32(userProof[i]);
        }

        vm.expectRevert("INSOMNIA: Phase 1 not active");
        minter.mint(proof);

        vm.stopPrank();
    }

    function test_Phase2SuccessfulMintWithDiscountAndEmitCheck() public {
        address user2 = 0xACc74cfaA8AD730194C1828cc179c78d5C08200e;
        string[] memory user2Proof =
            vm.parseJsonStringArray(merkle2Json, ".0xACc74cfaA8AD730194C1828cc179c78d5C08200e.proof");

        bytes32[] memory proof = new bytes32[](user2Proof.length);

        for (uint256 i = 0; i < user2Proof.length; i++) {
            proof[i] = vm.parseBytes32(user2Proof[i]);
        }
        uint256 discount = 20;

        bytes32 messageHash = keccak256(abi.encodePacked(user2, proof, discount));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE2);
        minter.setRoot(merkleRoot2);
        feeToken.transfer(user2, 5_000 ether);

        vm.stopPrank();

        // Whhitelisted user mint with discount
        vm.startPrank(user2);

        uint256 feeWithDiscount = mintFee - (mintFee * discount / 100);

        feeToken.safeIncreaseAllowance(address(minter), feeWithDiscount);

        vm.expectEmit(address(minter));
        emit Minter.Mint(user2, 1);
        minter.mintWithDiscount(signature, proof);

        uint256 balance = minter.balanceOf(user2);
        assert(balance == 1);

        vm.stopPrank();
    }

    function test_RevertWhen_SignatureInvalid() public {
        address user2 = 0xACc74cfaA8AD730194C1828cc179c78d5C08200e;
        string[] memory user2Proof =
            vm.parseJsonStringArray(merkle2Json, ".0xACc74cfaA8AD730194C1828cc179c78d5C08200e.proof");

        bytes32[] memory proof = new bytes32[](user2Proof.length);

        for (uint256 i = 0; i < user2Proof.length; i++) {
            proof[i] = vm.parseBytes32(user2Proof[i]);
        }
        uint256 discount = 20;

        bytes32 messageHash = keccak256(abi.encodePacked(user2, proof, discount));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Compute signature with another verifying signer

        (, uint256 privateKey) = makeAddrAndKey("otherSigner");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE2);
        minter.setRoot(merkleRoot2);
        feeToken.transfer(user2, 5_000 ether);

        vm.stopPrank();

        vm.startPrank(user2);

        uint256 feeWithDiscount = mintFee - (mintFee * discount / 100);

        feeToken.safeIncreaseAllowance(address(minter), feeWithDiscount);

        vm.expectRevert("INSOMNIA: Invalid signature");
        minter.mintWithDiscount(signature, proof);

        vm.stopPrank();
    }

    function test_RevertWhen_Phase2InvalidProof() public {
        address user2 = 0x6b6481A6Fb950a7c24D6fC79731894553b909743;
        bytes32[] memory proof = new bytes32[](4);
        proof[0] = 0x6207bb34599074ca8e1db49a23287ecf8727a6429429f4084b28815e97919195;
        proof[1] = 0xb4350eb845d7f6e4e92d62bf03e66f931bee6f4cb5cfe5d4ff529c342c08329f;
        proof[2] = 0x284a228a7f6b821105b9cf515472f691b1d2a09ec5c0241a17cdb8fa91f442b8;
        proof[3] = 0xb4350eb845d7f6e4e92d62bf03e66f931bee6f4cb5cfe5d4ff529c342c08329f;

        uint256 discount = 20;

        bytes32 messageHash = keccak256(abi.encodePacked(user2, proof, discount));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE2);
        minter.setRoot(merkleRoot2);
        feeToken.transfer(user2, 5_000 ether);

        vm.stopPrank();

        vm.startPrank(user2);

        uint256 feeWithDiscount = mintFee - (mintFee * discount / 100);

        feeToken.safeIncreaseAllowance(address(minter), feeWithDiscount);

        vm.expectRevert("INSOMNIA: Invalid proof");
        minter.mintWithDiscount(signature, proof);

        vm.stopPrank();
    }

    function test_PublicMintAndEmit() public {
        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PUBLIC);
        feeToken.transfer(publicUser, 5_000 ether);

        vm.stopPrank();

        vm.startPrank(publicUser);
        feeToken.safeIncreaseAllowance(address(minter), mintFee);

        vm.expectEmit(address(minter));
        emit Minter.Mint(publicUser, 1);

        minter.mint();

        vm.stopPrank();
    }

    function testRevertWhen_PublicPhaseNotActive() public {
        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PHASE1);
        feeToken.transfer(publicUser, 5_000 ether);

        vm.stopPrank();

        vm.startPrank(publicUser);

        feeToken.safeIncreaseAllowance(address(minter), mintFee);
        vm.expectRevert("INSOMNIA: Public phase not active");
        minter.mint();

        vm.stopPrank();
    }

    function testRevertIf_ClaimedTwice() public {
        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PUBLIC);
        feeToken.transfer(publicUser, 5_000 ether);

        vm.stopPrank();

        vm.startPrank(publicUser);
        feeToken.safeIncreaseAllowance(address(minter), mintFee);

        // First claim
        minter.mint();

        // Second Claim
        vm.expectRevert("INSOMNIA: Address already claimed");
        minter.mint();

        vm.stopPrank();
    }
}

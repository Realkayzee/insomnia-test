// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BaseTest} from "./Base.t.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Minter} from "../src/Minter.sol";
import {Errors} from "@sablier/v2-core/src/libraries/Errors.sol";

contract MinterForkTest is BaseTest {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;

    function setUp() public override {
        super.setUp();
    }

    function usersMint() public {
        // discounted user mint
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

        vm.startPrank(user2);

        uint256 feeWithDiscount = mintFee - (mintFee * discount / 100);

        feeToken.safeIncreaseAllowance(address(minter), feeWithDiscount);
        minter.mintWithDiscount(signature, proof);

        vm.stopPrank();

        // Public user mint
        vm.startPrank(signer);

        minter.setPhase(Minter.Phase.PUBLIC);
        feeToken.transfer(publicUser, 5_000 ether);

        vm.stopPrank();

        vm.startPrank(publicUser);

        feeToken.safeIncreaseAllowance(address(minter), mintFee);
        minter.mint();

        vm.stopPrank();
    }

    function test_SuccesfulCreateLinerLockVesting() public {
        usersMint();

        // Lock the miniting fee in a linear vesting schedule
        vm.startPrank(signer);

        vm.deal(signer, 100_000 ether);

        minter.setPhase(Minter.Phase.END);

        vm.recordLogs();

        minter.toSablier();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertGt(entries.length, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_PhaseHasNotEnded() public {
        usersMint();

        // Attempt to lock when claiming phase hasn't ended
        vm.startPrank(signer);
        vm.deal(signer, 100_000 ether);

        vm.expectRevert("INSOMNIA: Minting processes still active");
        minter.toSablier();

        vm.stopPrank();
    }

    function test_SuccesfulWithdrawFromSablier() public {
        usersMint();

        // Lock the miniting fee in a linear vesting schedule
        vm.startPrank(signer);

        vm.deal(signer, 100_000 ether);

        minter.setPhase(Minter.Phase.END);
        uint256 _streamId = minter.toSablier();

        // Withdraw from Sablier
        vm.warp(block.timestamp + 104 weeks);

        uint128 withdrawableAmount = SABLIER.withdrawableAmountOf(_streamId);

        vm.recordLogs();
        SABLIER.withdraw(_streamId, signer, withdrawableAmount);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertGt(entries.length, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawBeforeTheEndOfCliff() public {
        usersMint();

        // Lock the miniting fee in a linear vesting schedule
        vm.startPrank(signer);

        vm.deal(signer, 100_000 ether);

        minter.setPhase(Minter.Phase.END);
        uint256 _streamId = minter.toSablier();

        // Withdraw from Sablier
        vm.warp(block.timestamp + 24 weeks);

        uint128 withdrawableAmount = SABLIER.withdrawableAmountOf(_streamId);

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_WithdrawAmountZero.selector, _streamId));
        SABLIER.withdraw(_streamId, signer, withdrawableAmount);

        vm.stopPrank();
    }
}

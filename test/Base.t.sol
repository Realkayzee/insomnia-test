// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Minter} from "../src/Minter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {MUsdt} from "../src/MUsdt.sol";

contract BaseTest is Test {
    Minter public minter;
    string base;
    address signer;
    uint256 signerPrivateKey;
    string merkle1Json;
    string merkle2Json;
    IERC20 feeToken;
    ISablierV2LockupLinear constant SABLIER = ISablierV2LockupLinear(0xFDD9d122B451F549f48c4942c6fa6646D849e8C1);
    uint256 mintFee;
    bytes32 merkleRoot2;
    address publicUser;

    function setUp() public virtual {
        (signer, signerPrivateKey) = makeAddrAndKey("signer");
        publicUser = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
        base = vm.projectRoot();

        string memory merkleProof1 = string.concat(base, "/script/ts/generators/merkleProof1.json");
        string memory merkleProof2 = string.concat(base, "/script/ts/generators/merkleProof2.json");

        merkle1Json = vm.readFile(merkleProof1); // get the merkle tree data for phase1
        merkle2Json = vm.readFile(merkleProof2); // get the merkle tree data for phase2

        bytes32 merkleRoot1 = vm.parseJsonBytes32(merkle1Json, ".merkleRoot");
        merkleRoot2 = vm.parseJsonBytes32(merkle2Json, ".merkleRoot");

        feeToken = new MUsdt(signer, 1_000_000 ether);
        mintFee = 500 ether;

        minter = new Minter(signer, merkleRoot1, feeToken, SABLIER, mintFee);
    }
}

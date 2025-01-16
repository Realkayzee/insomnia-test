## INSOMNIA DEVELOPER TEST

### Overview

This project demonstrate a whitelisted and public claiming pattern for an NFT token. The lifecycle of this project is divided into 5 phases

- The **PAUSED** phase is the default of the phases, servinf as a starting point as well as a break between various phases
- The **PHASE1** phase is for the special users that are whitelisted not to pay for claiming. This users are responsible with showing a proof (Merkle Proof) and claim on successful validation.
- The **PHASE2** phase is for the second class users that are whitelisted to pay for claiming at a discounted price. This users must show their proof as well as a verifying signer signature in order to proceed with their claiming.
- The **PUBLIC** phase is for any other person interested in claiming the utility token. They must pay some certain amount of fee before claiming.

### Contract Owner

Every change of phases is handled by the contract owner based on needs.

The contract owner is responsible for handling the merkle root update per required phases and also responsible to lock the fee accrued from token claim to Sablier.

### Sablier

The fee accrued from users payment for token claim is locked in Sablier for a period of 52 weeks (approx. 1 year) and can only be withdrawn by the contract owner.

### Test

The test covered a unit test and intergation test. The unit test can be ran as `forge test test/Minter.t.sol` covering scenerios for Phase1, Phase2 and public minting. Test case scenerios for invalid signatures & signature malleability, invalid proof, and signature replay.

The integration test can be ran as `forge test test/MinterFork.t.sol --fork-url <rpc-url-path> --etherscan-api-key <etherscan-api-key>` covering scenerios for Sablier integrations. The sablier withdraw is handled by direct interaction with the Seblier `SablierV2LockupLinear` contract due to difference in msg.sender when used within the `Minter.sol` contract

### Instructions For Cloning And Testing

- Step 1 - `git clone https://github.com/Realkayzee/insomnia-test.git`
- Step 2 - `forge install` to install foundry dependencies
- Step 3 - `yarn install` to install node dependencies
- Step 4 - `yarn generate` to generate merkle tree
- Step 5 - `forge test test/Minter.t.sol` for the first set of test case scenerio
- Step 6 - `forge test test/MinterFork.t.sol` for the second set of test case scenerio

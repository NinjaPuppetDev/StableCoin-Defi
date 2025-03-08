# DSC Engine Test Suite

## Overview
This test suite verifies the functionality of the `DSCEngine` smart contract. The contract handles collateral deposits, DSC (Decentralized Stable Coin) minting and burning, liquidation mechanisms, and security constraints.

## Running the Tests
To execute the test suite, run the following command in the Foundry environment:

```sh
forge test
```

## Test Summary
Below is a list of the tests executed in `test/unit/TestDSCEngine.sol:TestDSCEngine`, along with their respective gas usage:

### Passing Tests:
- **testCanDepositCollateralAndGetAccountInfo()** *(gas: 132410)*  
  *Ensures users can deposit collateral and retrieve account information correctly.*

- **testCanMintDSC()** *(gas: 206739)*  
  *Verifies that users can successfully mint DSC tokens against their collateral.*

- **testGetUsdValue()** *(gas: 28331)*  
  *Checks the USD valuation function for accuracy.*

- **testLiquidationPayIsCorrect()** *(gas: 527640)*  
  *Ensures liquidation payments are calculated correctly.*

- **testOtherUserCanNOTLiquidateTheUserBecauseHeIsOKE()** *(gas: 250308)*  
  *Verifies that liquidation is not possible if the user's collateralization ratio is sufficient.*

- **testUserCanBurnAndRedeemCollateralForDToken()** *(gas: 132390)*  
  *Tests if users can burn DSC and redeem their collateral.*

- **testUserCanBurnDSC()** *(gas: 242901)*  
  *Verifies that users can burn DSC to reduce their debt.*

- **testgetTokenAmountFromUsd()** *(gas: 28353)*  
  *Checks conversion calculations from USD to token amounts.*

### Reverting Tests:
- **testRevertTokenLengthDoesNotMach()** *(gas: 184637)*  
  *Ensures the contract reverts when the token list length does not match expected input.*

- **testRevertUnapprovedCollateral()** *(gas: 952013)*  
  *Verifies that only approved collateral assets can be used.*

- **testRevertsIfCollateralZero()** *(gas: 43396)*  
  *Ensures that collateral deposits of zero are rejected.*

- **testUserCantMintZeroDSCAndRunAwayWithIt()** *(gas: 83783)*  
  *Prevents users from minting zero DSC and exploiting the system.*

## Notes
- Gas costs are indicative and may vary slightly depending on execution conditions.
- Reverting tests are expected to fail as part of the contract’s security mechanisms.
- This suite ensures the `DSCEngine` operates securely and efficiently in managing decentralized stablecoin issuance.


# StableCoin-Defi

![UnitedCrowd](https://staging.unitedcrowd.com/github/uc-Logos-gr-l.jpg)
# STO Contract
## United Token Features
### Freezable Accounts
Any user account can be frozen/unfrozen by the admin.
Call the `reezeAccount(address _target)` & `unFreezeAccount(address _target)` function respectively.

### Pausable Contract
All token transfers among any users can be paused/un-paused by the admin in case of an unforeseen
circumstance.
Call the `pause()` & `unPause()` function respectively.

### Vest Tokens to An Independent Address
Admin can create vesting schedules for users, such that the tokens are not given out immediately, but are
distributed over a period of time in small quantities. The tokens are stored in an independent address until they
vest.

The following functionality is available to the admin:
- Create a vesting schedule: `grantVestedTokens(address beneficiary, uint fullyVestedAmount, uint startDate, uint cliffSec, uint durationSec, bool isRevokable)`
 - Remove a vesting schedule: revokeVesting `(address beneficiary)`

The following functionality is available to a user:
- Withdraw vested tokens if any: `releaseVestedTokens(address beneficiary)`

Dividend paying tokens
Admin can send the profit earned to the contract (in Ether) using the `addDividend()` function.
This is then automatically distributed among the current token holders the next time they send/recieve a
payment. In the ratio of the number of tokens they hold. No additional function needs to be called by the users.

<h1 class="clause">user_authority</h1>
The signer authorizes only the state transition described by this action and acknowledges that blockchain transactions are public and irreversible.

<h1 class="clause">issuer_authority</h1>
This action is restricted to the contract account or the account recorded as the token issuer. The issuer is responsible for the token's monetary policy and for validating supply and fee values before signing.

<h1 class="clause">dual_authority</h1>
This action requires two independent signatures: the account currently recorded as issuer, and the contract account itself. Neither key alone can move the authority to mint or retire this token. The signers accept that after this action the previous issuer permanently loses that authority.

<h1 class="clause">supply_finality</h1>
The maximum supply is fixed when the symbol is created and cannot be raised by any action in this contract. Tokens issued within that ceiling enter circulation immediately.

<h1 class="clause">irreversible_destruction</h1>
Tokens destroyed by this action are removed from circulating supply and cannot be recovered. The maximum supply is unchanged, so the destroyed amount may be issued again by the issuer at a later time.

<h1 class="clause">transfer_fee</h1>
A transfer fee may apply. Where it does, the sender is debited the full stated quantity, the recipient is credited the quantity less the fee, and the fee is permanently destroyed rather than paid to any party. The fee rate is published on-chain and is zero when either the sender or the recipient holds a fee exemption. Recipients should read their resulting balance rather than assume the stated quantity was delivered in full.

<h1 class="clause">fee_policy</h1>
This action changes who pays the transfer fee, or how much it is. The rate is bounded by the contract and cannot be raised beyond that ceiling. An increase to an already-active fee cannot take effect until the published notice period has elapsed. A fee cannot be brought into force while no exemption is locked.

<h1 class="clause">exemption_lock</h1>
A locked exemption cannot be deleted, and cannot be unlocked while any transfer fee is in force. This protects contracts whose internal accounting depends on receiving the full transferred amount. The signer accepts that releasing such an exemption requires first setting every transfer fee to zero.

<h1 class="clause">receipt_only</h1>
This action records information in the transaction history and changes no balance, supply, or configuration. It can be authorized only by the contract itself and notifies no other account.

<h1 class="clause">memo_visibility</h1>
The memo is stored in the public transaction history, is readable by anyone, and may be interpreted as an instruction by a receiving smart contract.

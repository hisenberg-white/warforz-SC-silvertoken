<h1 class="contract">create</h1>
Register the token symbol and fix its permanent maximum supply. {{issuer_authority}} {{supply_finality}}
<h1 class="contract">issue</h1>
Mint new tokens into the issuer balance, up to the maximum supply. {{issuer_authority}} {{supply_finality}}
<h1 class="contract">retire</h1>
Permanently destroy tokens held by the issuer, reducing circulating supply. {{issuer_authority}} {{irreversible_destruction}}
<h1 class="contract">setissuer</h1>
Transfer the authority to mint and retire this token to {{new_issuer}}. {{dual_authority}}
<h1 class="contract">transfer</h1>
Transfer {{quantity}} from {{from}} to {{to}}. {{user_authority}} {{transfer_fee}} {{memo_visibility}}
<h1 class="contract">open</h1>
Create a zero balance row for an account, paid for by the signing RAM payer. {{user_authority}}
<h1 class="contract">close</h1>
Delete the signer's zero balance row and reclaim its RAM. {{user_authority}}
<h1 class="contract">burn</h1>
Permanently destroy {{quantity}} from the signer's own balance, reducing circulating supply. {{user_authority}} {{irreversible_destruction}}
<h1 class="contract">setfee</h1>
Set the burned transfer fee rate for this symbol. A reduction takes effect at once; an increase is announced and takes effect only after the published notice period. {{issuer_authority}} {{fee_policy}}
<h1 class="contract">feeapply</h1>
Put a previously announced fee increase into effect after its notice period has elapsed. {{issuer_authority}} {{fee_policy}}
<h1 class="contract">feecancel</h1>
Abandon an announced fee increase before it takes effect. {{issuer_authority}}
<h1 class="contract">exemptadd</h1>
Excuse an account from the transfer fee in both directions. {{issuer_authority}} {{fee_policy}}
<h1 class="contract">exemptlock</h1>
Mark a fee exemption as load-bearing, so it cannot be removed while a fee is in force. {{issuer_authority}} {{exemption_lock}}
<h1 class="contract">exemptunlock</h1>
Release a load-bearing fee exemption. Permitted only while every transfer fee is set to zero. {{issuer_authority}} {{exemption_lock}}
<h1 class="contract">exemptdel</h1>
Remove an account's transfer-fee exemption. {{issuer_authority}} {{fee_policy}}
<h1 class="contract">logburn</h1>
Record that a transfer fee of {{fee}} was destroyed. {{receipt_only}}

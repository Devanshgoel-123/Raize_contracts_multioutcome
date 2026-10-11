# Raize_contracts_multioutcome

### Multi-outcome prediction market contracts for Raize Club on Starknet

![Cairo](https://img.shields.io/badge/Cairo-EC796B?logo=starknet&logoColor=white) ![Starknet](https://img.shields.io/badge/Starknet-EC796B?logo=starknet&logoColor=white)

`MarketFactory` is a Cairo contract that creates prediction markets with more than two outcomes. Users buy outcome shares, and winners claim payouts after resolution. The platform takes a fee into a treasury wallet.

| Area | Functions |
|---|---|
| Markets | `create_multi_outcome_market`, `create_share_tokens`, `get_market`, `get_all_multioutcome_markets`, `get_multi_outcome_market_count` |
| Trading | `buy_shares`, `get_outcome_and_bet`, `get_num_bets_in_market` |
| Settlement | `claim_winnings` |
| Admin | `add_admin`, `check_is_admin`, `get_owner`, `get_platform_fee`, `get_treasury_wallet` |

```mermaid
flowchart LR
    Admin -->|create_multi_outcome_market| MF["MarketFactory"]
    User -->|buy_shares| MF
    MF --> Shares["Outcome share accounting"]
    MF -->|fee| T["Treasury wallet"]
    User -->|claim_winnings| MF
```

```bash
cd raize_multioutcome
scarb build
snforge test
```

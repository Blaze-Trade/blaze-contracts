# Quest Staking Contract

A decentralized quest platform built on Aptos using Move, where users can stake APT to participate in meme coin portfolio competitions with admin-determined winners and automatic reward distribution.

## 🎯 Overview

This contract implements a quest staking system where:
- **Admins** create quests with configurable parameters (entry fee, timing, etc.)
- **Users** join quests by paying entry fees in APT
- **Users** select meme coin portfolios (1-5 tokens) with USDC values
- **Admins** declare winners after quest completion
- **Smart contract** automatically distributes rewards to winners

## 🏗️ Architecture

### Core Data Structures

```move
// Quest status enumeration
public enum QuestStatus has store, copy, drop {
    Active,      // Accepting participants
    Closed,      // No more participants, waiting for results
    Completed,   // Winner declared, rewards distributed
    Cancelled,   // Quest cancelled, refunds processed
}

// Token selection in portfolio
public struct TokenSelection has store, copy, drop {
    token_address: address,
    amount_usdc: u64, // Amount in USDC (6 decimals)
}

// User portfolio selection
public struct Portfolio has store, copy, drop {
    tokens: vector<TokenSelection>,
    total_value_usdc: u64,
    selected_at: u64,
}

// Quest information
public struct Quest has key, store, copy, drop {
    quest_id: u64,
    name: String,
    admin: address,
    entry_fee: u64,           // in APT (octas)
    buy_in_time: u64,          // timestamp when quest closes for new participants
    result_time: u64,          // timestamp when results can be declared
    status: QuestStatus,
    participants: vector<address>,
    total_pool: u64,
    winner: Option<address>,
    created_at: u64,
}

// User participation record
public struct Participation has key, store, copy, drop {
    quest_id: u64,
    user: address,
    portfolio: Option<Portfolio>,
    entry_fee_paid: u64,
    joined_at: u64,
}
```

## 🔧 Key Functions

### Admin Functions

#### `create_quest(admin, name, entry_fee, buy_in_time, result_time)`
- Creates a new quest with specified parameters
- Only the contract admin can create quests
- Validates entry fee > 0 and result_time > buy_in_time

#### `declare_winner(admin, quest_id, winner)`
- Declares a winner for a completed quest
- Only callable after result_time has passed
- Automatically distributes the total pool to the winner
- Updates quest status to Completed

### User Functions

#### `join_quest(user, quest_id)`
- Allows users to join a quest by paying the entry fee
- Transfers APT from user to admin (who holds the pool)
- Creates a participation record
- Only callable while quest is Active and before buy_in_time

#### `select_portfolio(user, quest_id, token_addresses, amounts_usdc)`
- Allows users to select their meme coin portfolio
- Validates portfolio size (1-5 tokens)
- Calculates total USDC value
- Only callable after joining the quest

### View Functions

#### `get_quest_info(quest_id): Quest`
- Returns complete quest information

#### `get_user_participation(user, quest_id): Participation`
- Returns user's participation details

#### `get_all_quests(): vector<Quest>`
- Returns all quests in the system

#### `get_quest_participants(quest_id): vector<address>`
- Returns all participants for a specific quest

## 🧪 Testing

The contract includes comprehensive test coverage using test-driven development:

```bash
aptos move test
```

### Test Coverage

✅ **Quest Creation Tests**
- `test_create_quest` - Basic quest creation functionality
- `test_non_admin_cannot_create_quest` - Admin-only access control
- `test_create_quest_with_zero_entry_fee` - Input validation

✅ **Quest Participation Tests**
- `test_join_nonexistent_quest` - Error handling for invalid quests
- `test_select_portfolio_without_participation` - Participation requirement validation

✅ **Portfolio Selection Tests**
- `test_select_empty_portfolio` - Minimum portfolio size validation
- `test_select_too_many_tokens` - Maximum portfolio size validation

## 🚀 Usage Example

### 1. Admin Creates Quest
```move
quest_staking::create_quest(
    admin,
    string::utf8(b"Memecoin Madness"),
    100000000, // 1 APT entry fee
    3600,      // 1 hour buy-in period
    7200       // 2 hour result period
);
```

### 2. User Joins Quest
```move
quest_staking::join_quest(user, 1);
```

### 3. User Selects Portfolio
```move
let token_addresses = vector[@0x1111, @0x2222, @0x3333];
let amounts_usdc = vector[1000000, 2000000, 3000000]; // 1, 2, 3 USDC
quest_staking::select_portfolio(user, 1, token_addresses, amounts_usdc);
```

### 4. Admin Declares Winner
```move
quest_staking::declare_winner(admin, 1, winner_address);
```

## 🔒 Security Features

- **Admin Controls**: Only designated admin can create quests and declare winners
- **Time-based Validation**: Quest phases are enforced by timestamps
- **Input Validation**: All parameters are validated (entry fees, portfolio sizes, etc.)
- **Participation Tracking**: Prevents double participation and ensures proper state transitions
- **Resource Safety**: Uses Move's resource model for safe state management

## 📊 Events

The contract emits events for all major actions:

- `QuestCreatedEvent` - When a new quest is created
- `QuestJoinedEvent` - When a user joins a quest
- `PortfolioSelectedEvent` - When a user selects their portfolio
- `WinnerDeclaredEvent` - When a winner is declared and rewards distributed

## 🛠️ Development

### Prerequisites
- Aptos CLI
- Move development environment

### Setup
```bash
# Clone the repository
git clone <repository-url>
cd quest-staking/move

# Install dependencies
aptos move compile

# Run tests
aptos move test
```

### Deployment
```bash
# Deploy to testnet
aptos move publish --profile testnet

# Deploy to mainnet
aptos move publish --profile mainnet
```

## 🔮 Future Enhancements

- **Price Oracle Integration**: Real-time meme coin price feeds
- **Automated Winner Selection**: Algorithm-based winner determination
- **Multi-token Support**: Support for different entry fee tokens
- **Quest Categories**: Different types of quests with varying rules
- **Governance**: Community-driven quest creation and management
- **Frontend Integration**: React-based user interface

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For questions or support, please open an issue in the repository.

use starknet::{ContractAddress, Store, ClassHash};
use starknet::storage::{Map, ValidStorageTypeTrait};



#[derive(Drop, Serde, starknet::Store, starknet::Event)]
pub struct MultiOutcomeMarket {
    name: ByteArray,
    market_id: u256,
    description: ByteArray,
    outcomes: (Outcome, Outcome, Outcome, Outcome),
    no_of_outcomes: u8,
    image: ByteArray,
    is_settled: bool,
    is_active: bool,
    deadline: u64,
    winning_outcome: Option<Outcome>,
    money_in_pool: u256,
}

#[derive(Copy, Serde, Drop, starknet::Store, PartialEq)]
pub struct Outcome {
    name: felt252,
    bought_shares: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct UserPosition {
    amount: u256,
    has_claimed: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct UserBet {
    outcome: Outcome,
    position: UserPosition
}



#[starknet::interface] //this is the interface declaring the functions and its parameters of the contract we will write
pub trait IMarketFactory<TContractState> {
    //Interfaces represent the blueprint of the contract. They define the functions that the contract exposes to the outside world, without including the function body.
    fn create_multi_outcome_market(
        ref self: TContractState,
        name : ByteArray,
        description : ByteArray,
        outcomes : (felt252, felt252, felt252, felt252),
        no_of_outcomes : u8,
        image : ByteArray,
        deadline : u64 
    );

    fn get_multi_outcome_market_count(self: @TContractState) -> u256;

    fn buy_shares(
        ref self: TContractState, market_id: u256, token_to_mint: u8, amount: u256
    ) -> bool;

    fn settle_market(ref self: TContractState, market_id: u256, winning_outcome: u8);

    fn claim_winnings(ref self: TContractState, market_id: u256, bet_num: u8);

    fn get_market(self: @TContractState, market_id: u256) -> MultiOutcomeMarket;

    fn get_all_multioutcome_markets(self: @TContractState) -> Array<MultiOutcomeMarket>;

    fn get_user_markets(self: @TContractState, user: ContractAddress) -> Array<MultiOutcomeMarket>;

    fn get_owner(self: @TContractState) -> ContractAddress;

    fn get_treasury_wallet(self: @TContractState) -> ContractAddress;

    fn set_treasury_wallet(ref self: TContractState, wallet: ContractAddress);

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    fn get_num_bets_in_market(self: @TContractState, user: ContractAddress, market_id: u256) -> u8;

    fn get_outcome_and_bet(
        self: @TContractState, user: ContractAddress, market_id: u256, bet_num: u8
    ) -> UserBet;

    fn get_user_total_claimable(self: @TContractState, user: ContractAddress) -> u256;

    fn toggle_market(ref self: TContractState, market_id: u256);

    fn add_admin(ref self: TContractState, admin: ContractAddress);

    fn remove_all_markets(ref self: TContractState);

    fn set_platform_fee(ref self: TContractState, fee: u256);

    fn get_platform_fee(self: @TContractState) -> u256;

}



#[starknet::contract]
pub mod MarketFactory  {
    use starknet::event::EventEmitter;
    use super::{MultiOutcomeMarket, UserBet, UserPosition, Outcome};
    use starknet::{ContractAddress, ClassHash, get_caller_address, get_contract_address, syscalls, contract_address_const, get_block_timestamp};
    use starknet::class_hash::class_hash_const;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::num::traits::Zero;
    // use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        multioutcome_market_idx : u256,
        multioutcome_markets : Map<u256, MultiOutcomeMarket>,
        user_bet: Map<(ContractAddress, u256, u8), UserBet>, // ( user, market_id, bet_number)
        num_bets: Map<(ContractAddress, u256), u8>,
        owner: ContractAddress,
        treasury_wallet: ContractAddress,
        admins: Map<u128, ContractAddress>,
        num_admins: u128,
        platform_fee: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event{
        MarketCreated : MarketCreated,
        ShareBought: ShareBought,
        MarketSettled: MarketSettled,
        MarketToggled: MarketToggled,
        WinningsClaimed: WinningsClaimed,
        Upgraded: Upgraded,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Upgraded {
        pub class_hash: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    struct MarketCreated {
        market : MultiOutcomeMarket
    }

    #[derive(Drop, starknet::Event)]
    struct ShareBought {
        user: ContractAddress,
        market: MultiOutcomeMarket,
        outcome: Outcome,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct MarketSettled {
        market : MultiOutcomeMarket
    }

    #[derive(Drop, starknet::Event)]
    struct MarketToggled {
        market: MultiOutcomeMarket
    }

    #[derive(Drop, starknet::Event)]
    struct WinningsClaimed {
        user: ContractAddress,
        market: MultiOutcomeMarket,
        outcome: Outcome,
        amount: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    fn create_share_tokens(names: (felt252, felt252, felt252, felt252)) -> (Outcome, Outcome, Outcome, Outcome) {
        let (name1, name2, name3, name4) = names;
        let mut token1 = Outcome { name: name1, bought_shares: 0 };
        let mut token2 = Outcome { name: name2, bought_shares: 0 };
        let mut token3 = Outcome { name: name3, bought_shares: 0 };
        let mut token4 = Outcome { name: name4, bought_shares: 0 };

        let tokens = (token1, token2, token3, token4);

        return tokens;
    }

    fn check_is_admin(self : @ContractState, caller : ContractAddress) -> bool { 
        let admins_idx = self.num_admins.read();
        let mut i = 1;
        while i != admins_idx + 1 {
            if ( self.admins.read(i) == caller ) {
                return true;
            }
            i += 1;
        }
        false 
    }

    #[abi(embed_v0)]
    impl MarketFactory of super::IMarketFactory<ContractState> {

        fn create_multi_outcome_market(
            ref self: ContractState,
            name: ByteArray,
            description: ByteArray,
            outcomes: (felt252, felt252, felt252, felt252),
            no_of_outcomes : u8,
            image: ByteArray,
            deadline: u64,
        ) {
            let is_admin_check = check_is_admin(@self, get_caller_address());
            assert(is_admin_check, 'Only admins can create markets');
            let market_outcomes= create_share_tokens(outcomes);
            let market_id=self.multioutcome_market_idx.read() + 1;
            let multi_outcome_market_new = MultiOutcomeMarket {
                name,
                market_id : market_id,
                description,
                outcomes: market_outcomes,
                no_of_outcomes,
                image,
                is_settled : false,
                is_active : true,
                deadline,
                winning_outcome : Option::None,
                money_in_pool : 0
            };
            self.multioutcome_market_idx.write(market_id);
            self.multioutcome_markets.write(market_id, multi_outcome_market_new);
            let market_created =  self.multioutcome_markets.read(market_id);
            self.emit(MarketCreated { market: market_created });
        }

        fn get_multi_outcome_market_count(self : @ContractState) -> u256 {
            self.multioutcome_market_idx.read()
        }

        fn buy_shares(
            ref self: ContractState, market_id: u256, token_to_mint: u8, amount: u256
        ) -> bool{
            let usdc_address = contract_address_const::<
            0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
            >();
            let usdc_dispatcher = IERC20Dispatcher { contract_address: usdc_address };
            let mut market = self.multioutcome_markets.read(market_id);
            assert(market.is_active, 'Market not active.');
            assert(get_block_timestamp() < market.deadline, 'Market has expired.');
            let (mut outcome1, mut outcome2, mut outcome3, mut outcome4) = market.outcomes;
            let txn: bool = usdc_dispatcher.transfer_from(get_caller_address(), get_contract_address(), amount);
            usdc_dispatcher.transfer(self.treasury_wallet.read(), amount * self.platform_fee.read() / 100);

            let bought_shares = amount - amount * self.platform_fee.read() / 100;
            let money_in_pool = market.money_in_pool + bought_shares;

            if token_to_mint == 0 {
                outcome1.bought_shares += bought_shares;
            } else if token_to_mint == 1{
                outcome2.bought_shares += bought_shares;
            }else if token_to_mint == 2 {
                outcome3.bought_shares += bought_shares;
            }else{
                outcome4.bought_shares += bought_shares;
            }
            market.outcomes = (outcome1, outcome2, outcome3, outcome4);
            market.money_in_pool = money_in_pool;

            self.multioutcome_markets.write(market_id, market);
            self.num_bets.write(
                (get_caller_address(), market_id),
                self.num_bets.read((get_caller_address(), market_id)) + 1
            );
            self.user_bet.write(
                (
                    get_caller_address(),
                    market_id,
                    self.num_bets.read((get_caller_address(), market_id))
                ),
                UserBet {
                    outcome: if token_to_mint == 0 {
                        outcome1
                    } else if token_to_mint == 1 {
                        outcome2
                    } else if token_to_mint == 2{
                        outcome3
                    } else {
                        outcome4
                    },
                    position: UserPosition { amount: amount, has_claimed: false }
                }
            );
            let new_market = self.multioutcome_markets.read(market_id);
            self.emit(ShareBought {
                        user: get_caller_address(),
                        market: new_market,
                        outcome: if token_to_mint == 0 {
                            outcome1
                        } else if token_to_mint == 1 {
                            outcome2
                        } else if token_to_mint == 2{
                            outcome3
                        } else {
                            outcome4
                        },
                        amount: amount
                    }
                );
            return txn;
        }

        fn settle_market(ref self: ContractState, market_id: u256, winning_outcome: u8) {
            let is_admin_check = check_is_admin(@self, get_caller_address());
            assert(is_admin_check, 'Only admins can settle markets');
            assert(market_id <= self.multioutcome_market_idx.read(), 'Market does not exist');
            let mut current_market = self.multioutcome_markets.read(market_id);
            assert(winning_outcome < current_market.no_of_outcomes, 'Please enter a valid outcome');
            current_market.is_settled = true;
            current_market.is_active = false;
            //winning_outcome expects an Option<Outcome> (which is either Some(Outcome) or None)
            let (outcome1, outcome2, outcome3, outcome4) = current_market.outcomes;
            //When you settle the market, you put the winning outcome inside the "box" by using Option::Some();
            if (winning_outcome == 0){
                current_market.winning_outcome = Option::Some(outcome1); 
            }else if(winning_outcome == 1){
                current_market.winning_outcome = Option::Some(outcome2);
            }else if(winning_outcome == 2){
                current_market.winning_outcome = Option::Some(outcome3);
            }else{
                current_market.winning_outcome = Option::Some(outcome4);
            }
            self.multioutcome_markets.write( market_id ,current_market);
            let market_settled = self.multioutcome_markets.read(market_id);
            self.emit( MarketSettled {
                market : market_settled
            })            
        }

        fn claim_winnings(ref self: ContractState, market_id: u256, bet_num: u8) {
            assert(market_id <= self.multioutcome_market_idx.read(), 'Market does not exist');
            let mut winnings = 0;
            let market = self.multioutcome_markets.read(market_id);
            assert(market.is_settled, 'Market not settled');
            let user_bet: UserBet = self.user_bet.read((get_caller_address(), market_id, bet_num));
            assert( !user_bet.position.has_claimed, 'User has claimed winnings.');
            let winning_outcome = market.winning_outcome.unwrap();
            assert(user_bet.outcome.name == winning_outcome.name, 'User did not win!');
            winnings = user_bet.position.amount
                * market.money_in_pool
                / winning_outcome.bought_shares;
            let usdc_address = contract_address_const::<
            0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
            >();
            let dispatcher = IERC20Dispatcher { contract_address: usdc_address };
            dispatcher.transfer(get_caller_address(), winnings);
            self.user_bet.write(
                    (get_caller_address(), market_id, bet_num),
                    UserBet {
                        outcome: user_bet.outcome,
                        position: UserPosition {
                            amount: user_bet.position.amount, has_claimed: true
                        }
                    }
                );
            self.emit(
                WinningsClaimed {
                        user: get_caller_address(),
                        market: market,
                        outcome: user_bet.outcome,
                        amount: winnings
                    }
            );
        }


        fn get_market(self: @ContractState, market_id: u256) -> MultiOutcomeMarket {
            return self.multioutcome_markets.read(market_id);
        }

        fn get_all_multioutcome_markets(self: @ContractState) -> Array<MultiOutcomeMarket> {
            let mut markets:Array<MultiOutcomeMarket> = ArrayTrait::new();
            let markets_length = self.multioutcome_market_idx.read();
            let mut i:u256=1;
            while i != markets_length + 1 {
                if self.multioutcome_markets.read(i).is_active {
                markets.append(self.multioutcome_markets.read(i));
            }
                i += 1;
            }
            markets
        }

        fn get_user_markets(self: @ContractState, user: ContractAddress) -> Array<MultiOutcomeMarket> {
            let mut user_markets:Array<MultiOutcomeMarket> = ArrayTrait::new();
            let markets_length= self.multioutcome_market_idx.read();
            let mut i:u256=1;
            while i != markets_length + 1 {
                if self.num_bets.read((user, i)) != 0 {
                user_markets.append(self.multioutcome_markets.read(i));
            }
                i += 1;
            }
            user_markets
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            return self.owner.read();
        }

        fn get_treasury_wallet(self: @ContractState) -> ContractAddress{
            return self.treasury_wallet.read();
        }

        fn set_treasury_wallet(ref self: ContractState, wallet: ContractAddress) {
            assert( get_caller_address() == self.owner.read(), 'Only Owner can set the wallet');
            self.treasury_wallet.write(wallet);
        }

        fn upgrade(ref self: ContractState , new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            syscalls::replace_class_syscall(new_class_hash).unwrap();
        }

        fn get_num_bets_in_market(self: @ContractState, user: ContractAddress, market_id: u256) -> u8 {
            return self.num_bets.read((user, market_id));
        }

        fn get_outcome_and_bet(self: @ContractState, user: ContractAddress, market_id: u256, bet_num: u8) -> UserBet{
            return self.user_bet.read((user, market_id, bet_num));
        }

        fn get_user_total_claimable(self: @ContractState, user: ContractAddress) -> u256 {
            let mut total_claimable = 0;
            let markets_length = self.multioutcome_market_idx.read();
            let mut i:u256 = 1;
            while i != markets_length + 1 {
                let current_market: MultiOutcomeMarket = self.multioutcome_markets.read(i);
                if current_market.is_settled {
                    let total_bets = self.num_bets.read((user, i));
                    let mut bet_num:u8 = 1;
                    while !total_bets.is_zero() && bet_num != total_bets + 1 {
                       let current_bet: UserBet = self.user_bet.read(( user, i, bet_num));
                       let outcome_name = current_bet.outcome.name;  // Moves outcome field
                       let position_amount = current_bet.position.amount;
                       let position_claimed = current_bet.position.has_claimed;
                       // Cloning the position to avoid moving it when accessed multiple times for my reference.
                       if outcome_name == current_market.winning_outcome.unwrap().name && !position_claimed {
                           total_claimable += position_amount
                           * current_market.money_in_pool
                           / current_market.winning_outcome.unwrap().bought_shares;
                       }
                       bet_num += 1;
                    } 
                }
                i += 1;
            }
            total_claimable
        }

        fn toggle_market(ref self: ContractState, market_id: u256) {
            assert( self.multioutcome_market_idx.read() >= market_id, 'Please enter a valid market Id');
            let is_admin= check_is_admin(@self, get_caller_address());
            assert( is_admin, 'Only Admins can toggle markets');
            let mut market = self.multioutcome_markets.read(market_id);
            market.is_active = !market.is_active;
            self.multioutcome_markets.write(market_id, market);
            let current_market = self.multioutcome_markets.read(market_id);
            self.emit(MarketToggled { market: current_market });
        }

        fn add_admin(ref self: ContractState, admin: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), 'Only owner can add admins.');
            self.num_admins.write(self.num_admins.read() + 1);
            self.admins.write(self.num_admins.read(), admin);
        }

        fn remove_all_markets(ref self: ContractState) {
            assert( self.owner.read() == get_caller_address(), 'Only Owner can remove markets');
            self.multioutcome_market_idx.write(0)
        }

        fn set_platform_fee(ref self: ContractState, fee: u256) {
            assert(get_caller_address() == self.owner.read(), 'Only owner can set.');
            self.platform_fee.write(fee);
        }

        fn get_platform_fee(self: @ContractState) -> u256 {
            return self.platform_fee.read();
        }

    }

   
}

use starknet::{ContractAddress, ClassHash, Store};
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

    // fn buy_shares(
    //     ref self: TContractState, market_id: u256, token_to_mint: u8, amount: u256
    // ) -> bool;

    fn settle_market(ref self: TContractState, market_id: u256, winning_outcome: u8);

    // fn claim_winnings(ref self: TContractState, market_id: u256, bet_num: u8);

    // fn get_market(self: @TContractState, market_id: u256) -> MultiOutcomeMarket;

    // fn get_al_multioutcome_markets(self: @TContractState) -> Array<MultiOutcomeMarket>;

    // fn get_user_markets(self: @TContractState, user: ContractAddress) -> Array<MultiOutcomeMarket>;

    // fn get_owner(self: @TContractState) -> ContractAddress;

    // fn get_treasury_wallet(self: @TContractState) -> ContractAddress;

    // fn set_treasury_wallet(ref self: TContractState, wallet: ContractAddress);

    // fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    // fn get_num_bets_in_market(self: @TContractState, user: ContractAddress, market_id: u256) -> u8;

    // fn get_outcome_and_bet(
    //     self: @TContractState, user: ContractAddress, market_id: u256, bet_num: u8
    // ) -> UserBet;

    // fn get_user_total_claimable(self: @TContractState, user: ContractAddress) -> u256;

    // fn toggle_market(ref self: TContractState, market_id: u256);

    // fn add_admin(ref self: TContractState, admin: ContractAddress);

    // fn remove_all_markets(ref self: TContractState);

    // fn set_platform_fee(ref self: TContractState, fee: u256);

    // fn get_platform_fee(self: @TContractState) -> u256;

}



#[starknet::contract]
pub mod MarketFactory  {
    use starknet::event::EventEmitter;
use super::{MultiOutcomeMarket, UserBet, UserPosition, Outcome};
    use starknet::{ContractAddress, ClassHash, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        multioutcome_market_idx : u256,
        multioutcome_markets : Map<u256, MultiOutcomeMarket>,
        user_bet: Map<(ContractAddress, u256, u8, u8), UserBet>,
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


    }

   
}

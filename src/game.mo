import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Nat "mo:base/Bool";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import Result "mo:base/Result";

import Metascore "mo:metascore/Metascore";
import Player "mo:metascore/Player";

shared ({ caller = owner }) actor class Metagame () : async Metascore.GameInterface = self {

    let metascore : Metascore.MetascoreInterface = actor("rl4ub-oqaaa-aaaah-qbi3a-cai");
    let controller : actor { register : (p : Principal) -> async (); } = actor("drpx4-jqaaa-aaaah-qblza-cai");
    var maxScore = 1;
    var name = "A Game";
    
    public shared func init (n : ?Text) : async () {
        let randomness = Random.Finite(await Random.blob());
        maxScore := do {
            switch (randomness.byte()) {
                case null 1;
                case (?seed) { Int.abs(Float.toInt(Float.fromInt(Nat8.toNat(seed)) / 255.0 * 1_000_000_000_000.0)); };
            };
        };
        switch (n) {
            case (?n) name := n;
            case null ();
        };
    };

    public query func metascoreScores() : async [Metascore.Score] {
        [];
    };

    public shared func metascoreRegisterSelf(callback : Metascore.RegisterCallback) : async () {
        await callback({
            name;
        });
    };

    public func register () : async Result.Result<(), Text> {
        await controller.register(Principal.fromActor(self));
        await metascore.register(Principal.fromActor(self));
    };

    public shared func score (player : Player.Player) : async () {
        let randomness = Random.Finite(await Random.blob());
        let score = do {
            switch (randomness.byte()) {
                case null throw Error.reject("Randomness failure");
                case (?seed) { Int.abs(Float.toInt(Float.fromInt(Nat8.toNat(seed)) / 255.0 * Float.fromInt(maxScore))); };
            };
        };
        let newScore : Metascore.Score = (player, score);
        Debug.print("Player scored " # Int.toText(score));
        await metascore.scoreUpdate([newScore]);
    };

    public query func wallet_balance () : async Nat {
        Cycles.balance();
    };

    public func wallet_receive () : async Nat {
        Cycles.accept(Cycles.available());
    };
};

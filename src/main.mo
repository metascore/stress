import Array "mo:base/Array";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import Text "mo:base/Text";

import Player "mo:metascore/Player";

import Base32 "base32";
import Crc32 "crc32";


actor {
    stable var players : [Principal] = [];
    stable var playerCount = 0;

    stable var games : [Principal] = [];

    public func init (numPlayers : Nat) : async () {
        // Add players
        playerCount := numPlayers;
        players := Array.tabulate<Principal>(numPlayers, func (i : Nat) : Principal {
            bytesToPrincipal(natToBytes(i));
        });

        scoringOffset := 0.0;

        Debug.print(Nat.toText(playerCount) # " Players");
    };

    // Allow simulation game cans to register with the controller
    public func register (can : Principal) {
        games := Array.append(games, [can]);
    };

    // Simulate some players getting scores...
    // Most likely scores will happen infrequently during play
    // Therefor 100 concurrent users might result in ~10 scores per second (generously)
    // This will vary with each game, so we can tweak this number to test a variable average
    // However, there will be spikes... 🤔
    let scoreRate = 0.1;
    // We will use this to determine which players score in each pulse
    var scoringOffset = 0.0;
    public func pulse () : async () {
        // Select the chunk of players to score in this pulse
        let a = Int.abs(Float.toInt(scoringOffset * Float.fromInt(playerCount)));
        let b = a + Int.abs(Float.toInt(Float.fromInt(playerCount) * scoreRate));
        Debug.print("Simulating players #" # Nat.toText(a) # "-" # Nat.toText(b));
        for (i in Iter.range(a, b)) {
            try {
                ignore simPlayer(players[i]);
            } catch (e) {
                Debug.print("Simulation failed: " # Error.message(e));
            };
        };
        // Move the cursor for the next pulse
        scoringOffset := scoringOffset + scoreRate;
        if (scoringOffset >= 1) scoringOffset := 0;
    };

    func simPlayer (player : Principal) : async () {
        let randomness = Random.Finite(await Random.blob());
        let gamePrincipal = do {
            switch (randomness.byte()) {
                case null throw Error.reject("Randomness failure");
                case (?seed) { games[Int.abs(Float.toInt(Float.fromInt(Nat8.toNat(seed)) / 255.0 * Float.fromInt(games.size())))]; };
            };
        };
        let game : actor { score : (player : Player.Player) -> async () } = actor(Principal.toText(gamePrincipal));
        try {
                await game.score(#stoic(player));
            } catch (e) {
                Debug.print("Scoring failed: " # Error.message(e));
            };
        // Debug.print("Simulate player " # Principal.toText(player) # " game " # Principal.toText(gamePrincipal));
    };


    // Not important ---------

    public query func wallet_balance () : async Nat {
        Cycles.balance();
    };

    public func wallet_receive () : async Nat {
        Cycles.accept(Cycles.available());
    };

    func bytesToPrincipal(_bytes: [Nat8]) : Principal {
        var res: [Nat8] = [];
        res := Array.append(res, Crc32.crc32(_bytes));
        res := Array.append(res, _bytes);
        let s = Base32.encode(#RFC4648 {padding=false}, res);
        let lowercase_s = make_ascii_lowercase(s);
        // let lowercase_s = Text.map(s , Prim.charToLower);
        let len = lowercase_s.size();
        let s_slice = Iter.toArray(Text.toIter(lowercase_s));
        var ret = "";
        for (i in Iter.range(0, len-1)) {
            ret := ret # Char.toText(s_slice[i]);
            if ((i+1) % 5 == 0 and i !=len-1) {
                ret := ret # "-";
            };
        };
        return Principal.fromText(ret);
    };

    func make_ascii_lowercase(a: Text) : Text {
        var bytes: [var Nat8] = Iter.toArrayMut(Iter.map<Char, Nat8>(Text.toIter(a), char_to_nat8));
        for (i in bytes.keys()) {
            bytes[i] := to_ascii_lowercase(bytes[i]);
        };
        var res = "";
        for (v in  Iter.map<Nat8, Char>(bytes.vals(), nat8_to_char)) {
            res := res # Char.toText(v);
        };
        return res;
    };

    func char_to_nat8(a: Char) : Nat8 {
        return Nat8.fromNat(Nat32.toNat(Char.toNat32(a)));
    };

    func nat8_to_char(a: Nat8) : Char {
        return Char.fromNat32(Nat32.fromNat(Nat8.toNat(a)));
    };

    func to_ascii_lowercase(a: Nat8) : Nat8 {
        if (is_ascii_uppercase(Char.fromNat32(Nat32.fromNat(Nat8.toNat(a))))) {
            return 32 ^ a;
        } else {
            return a;
        };
    };

    func is_ascii_uppercase(a: Char) : Bool {
        return (a >= 'A' and a <= 'Z');
    };

    func natToBytes(n : Nat) : [Nat8] {
        var a = 0;
        var b = n;
        var bytes : [Nat8] = [];
        var test = true;
        while test {
            a := b % 256;
            b := b / 256;
            bytes := Array.append(bytes, [Nat8.fromNat(a)]);
            test := b > 0;
        };
        bytes
    };
};
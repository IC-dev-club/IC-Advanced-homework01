
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Array "mo:base/Array";

import Logger "mo:ic-logger/Logger";
import TextLogger "./TextLogger";

shared(msg) actor class LoggerFactory() {
    private let OWNER = msg.caller;
    private var LOGGER_SIZE : Nat = 100;
    private var loggerMap = TrieMap.TrieMap<Nat, Principal>(Nat.equal, Hash.hash);
    private var loggerNum:Nat = 0;
    private var currentLoggerLength:Nat = 100; // init:100 to create new logger
    private var msgTotalNum:Nat = 0;


    private type TextLoggerActor = actor {
        append : shared (msgs : [Text]) -> async ();
        view : query (from: Nat, to: Nat) -> async Logger.View<Text>;
        // stats : query () -> async Logger.Stats;
    };

    public shared func view(from: Nat, to: Nat) : async [Text] {
        assert(from <= to and from >= 0 and to <= msgTotalNum);
        var result : Buffer.Buffer<Text> = Buffer.Buffer<Text>(0);
        let fromLoggerId:Nat = from/LOGGER_SIZE;
        let toLoggerId:Nat = to/LOGGER_SIZE;
        for (i in Iter.range(from, to)) {
            let logger = loggerMap.get(i);
            let fromMsgIndex = switch (i == from) {
                case (true) { from - fromLoggerId * LOGGER_SIZE };
                case (false) { 0 };
            };
            let toMsgIndex = switch (i == to) {
                case (true) { to - toLoggerId * LOGGER_SIZE };
                case (false) { LOGGER_SIZE - 1 };
            };
            var msgs : Logger.View<Text> = await logger.view(fromMsgIndex, toMsgIndex);
            if(msgs.messages.size() > 0) {
                for(k in Iter.range(0, msgs.messages.size() - 1)) {
                    result.add(msgs.messages[k]);
                };
            };
        };
        result.toArray();
    }

    public shared func append(msgs: [Text]) {
        for(msg in msgs.vals()) {
            await _createLogger();
            let logger = loggerMap.get(loggerNum - 1);
            logger.append(Array.make(msg));
            msgTotalNum := msgTotalNum + 1;
            currentLoggerLength := currentLoggerLength + 1;
        };
    };

    private func _createLogger() : async () {
        if(LOGGER_SIZE <= currentLoggerLength) {
            let newLogger = await TextLogger.TextLogger();
            let principal = Principal.fromActor(newLogger);
            loggerMap.put(loggerNum, principal);
            loggerNum := loggerNum + 1;
            currentLoggerLength := 0;
        }
    };

}
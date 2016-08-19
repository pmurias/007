use v6;
use Test;
use _007::Test;

emits-js q:to '====', [], q:to '----', "empty program";
    ====
    ----

emits-js q:to '====', ["say"], q:to '----', "hello world";
    say("Hello, world!");
    ====
    say("Hello, world!");
    ----

done-testing;

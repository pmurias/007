use _007::Q;
use _007::Runtime::Builtins;

class X::ParameterMismatch {
    has $.type;
    has $.paramcount;
    has $.argcount;

    method message {
        "$.type with $.paramcount parameters called with $.argcount arguments"
    }
}

role Frame {
    has $.block;
    has %.pad;
}

constant NO_OUTER = {};

role _007::Runtime {
    has $.output;
    has @!frames;

    submethod BUILD(:$output) {
        $!output = $output;
        my $setting = Val::Block.new(
            :outer-frame(NO_OUTER));
        self.enter($setting);
        self.load-builtins;
    }

    method run(Q::StatementList $statementlist) {
        my $compunit = Val::Block.new(
            :$statementlist,
            :outer-frame(self.current-frame));
        self.enter($compunit);

        $statementlist.run(self);
        self.leave;
        CATCH {
            when X::Control::Return {
                die X::ControlFlow::Return.new;
            }
        }
    }

    method enter($block) {
        my $frame = Frame.new(:$block);
        @!frames.push($frame);
        for $block.statementlist.static-lexpad.kv -> $name, $value {
            self.declare-var($name, $value);
        }
        for $block.statementlist.kv -> $i, $_ {
            when Q::Statement::Sub {
                my $name = .ident.name;
                my $parameterlist = .parameterlist;
                my $statementlist = .statementlist;
                my $outer-frame = $frame;
                my $val = Val::Sub.new(:$name, :$parameterlist, :$statementlist, :$outer-frame);
                self.put-var($name, $val);
            }
        }
    }

    method leave {
        @!frames.pop;
    }

    method unroll-to($frame) {
        until self.current-frame === $frame {
            self.leave;
        }
        return;
    }

    method current-frame {
        @!frames[*-1];
    }

    method !find($symbol) {
        my $frame = self.current-frame;
        repeat while $frame !=== NO_OUTER {
            return $frame.pad
                if $frame.pad{$symbol} :exists;
            $frame = $frame.block.outer-frame;
        }
        die X::Undeclared.new(:$symbol);
    }

    method put-var($name, $value) {
        my %pad := self!find($name);
        %pad{$name} = $value;
    }

    method get-var($name) {
        my %pad := self!find($name);
        return %pad{$name};
    }

    method declare-var($name, $value?) {
        self.current-frame.pad{$name} = Val::None.new;
        if defined $value {
            self.put-var($name, $value);
        }
    }

    method declared($name) {
        try self!find($name) && return True;
        return False;
    }

    method declared-locally($name) {
        my $frame = self.current-frame;
        return True
            if $frame.pad{$name} :exists;
    }

    method register-subhandler {
        self.declare-var("--RETURN-TO--");
        self.put-var("--RETURN-TO--", $.current-frame);
    }

    method load-builtins {
        my $builtins = _007::Runtime::Builtins.new(:runtime(self));
        for $builtins.get-subs.kv -> $name, $subval {
            self.declare-var($name, $subval);
        }
    }

    method sigbind($type, $c, @args) {
        my $paramcount = $c.parameterlist.elems;
        my $argcount = @args.elems;
        die X::ParameterMismatch.new(:$type, :$paramcount, :$argcount)
            unless $paramcount == $argcount;
        self.enter($c);
        for @($c.parameterlist) Z @args -> ($param, $arg) {
            my $name = $param.name;
            self.declare-var($name, $arg);
        }
    }

    multi method call(Val::Block $c, @args) {
        self.sigbind("Block", $c, @args);
        $c.statementlist.run(self);
        self.leave;
        return Val::None.new;
    }

    multi method call(Val::Sub $c, @args) {
        self.sigbind("Sub", $c, @args);
        self.register-subhandler;
        my $frame = self.current-frame;
        $c.statementlist.run(self);
        self.leave;
        CATCH {
            when X::Control::Return {
                die $_   # keep unrolling the interpreter's stack until we're there
                    unless .frame === $frame;
                self.unroll-to($frame);
                self.leave;
                return .value;
            }
        }
        return Val::None.new;
    }

    multi method call(Val::Sub::Builtin $c, @args) {
        my $result = $c.code.(|@args);
        return $result if $result;
        return Val::None.new;
    }

    method property($obj, $propname) {
        my $builtins = _007::Runtime::Builtins.new(:runtime(self));
        return $builtins.property($obj, $propname);
    }
}

use QRegex:from<NQP>;
use NQPHLL:from<NQP>;
use Data::Dump;

use _007::Q;
use nqp;

class _007::Backend::QAST {

    method NYI($msg = '') {
        my $prefixed-msg = 'NYI' ~ ($msg ?? ': ' ~ $msg !! '');
        QAST::Op.new(:op<say>, QAST::SVal.new(:value($prefixed-msg)));
    }

    multi method to-qast(Q::CompUnit $compunit) {
        QAST::CompUnit.new(self.to-qast($compunit.block));
    }

    multi method to-qast(Q::Block $block) {
        my @children = $block.statementlist.statements.elements.map({self.to-qast($^stmt)}); 
        QAST::Block.new(|@children);
    }

    multi method to-qast(Q::Statement::Expr $expr) {
        self.to-qast($expr.expr);
    }

    multi method to-qast(Q::Literal::Int $literal) {
        QAST::IVal.new(:value($literal.value.value));
    }

    multi method to-qast(Q::Literal::Str $literal) {
        QAST::SVal.new(:value($literal.value.value));
    }

    multi method to-qast(Q::Postfix::Call $call) {
        if $call.identifier.name eq 'postfix:()' {
            if $call.operand ~~ Q::Identifier && $call.operand.name.value eq "say" {
                QAST::Op.new(:op<say>, self.to-qast($call.argumentlist.arguments.elements[0]));
            }
        }
        else {
            self.NYI;
        }
    }

    multi method to-qast($ast) {
        say "NYI: " ~ $ast;
        self.NYI;
    }

    method compile($ast) {
        my $qast := self.to-qast($ast);

        say $ast.Str;


        say $qast.dump;

        my $hll := HLL::Compiler.new();

        my $compiled := $hll.compile($qast, :from<ast>);
        $compiled();

    }
}

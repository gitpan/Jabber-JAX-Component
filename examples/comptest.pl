use strict;
use Jabber::JAX::Component;

my $c = new Jabber::JAX::Component(
      component   => "echocomp",
      secret      => "mysecret",
      host        => "localhost",
      port        => "7000",
      handler     =>

      sub {
            my ( $rc, $p ) = @_;
            my $e = $p->getElement();
            my $to = $e->getAttrib('to');
            $e->putAttrib('to', $e->getAttrib('from'));
            $e->putAttrib('from', $to);
            $rc->deliver( $p );

          }
     );

$c->start();


use lib '../blib/lib';
use strict;
use Jabber::JAX::Component;

my $c = 0;

my $conn = new Jabber::JAX::Component(
      component   => "echocomp",
      secret      => "mysecret",
      host        => "localhost",
      port        => "7000",
      handler     =>

      sub {
            my ( $rc, $p ) = @_;
	    print STDERR "Doint number ".$c++."\n";
            my $e = $p->getElement();
            my $to = $e->getAttrib('to');
            $e->putAttrib('to', $e->getAttrib('from'));
            $e->putAttrib('from', $to);
            $rc->deliver( $p );
            $rc->stop() if $c == 50;

          }
     );

$conn->start();


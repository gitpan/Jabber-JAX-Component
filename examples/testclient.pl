use strict;
use lib '../blib/lib';
use Jabber::JAX::Client;
my $c = 0;
#$Jabber::JAX::Client::DEBUG = 1;

my $conn = new Jabber::JAX::Client(
      user        => "notify\@pxharding.dyndns.org/tester",
      passwd      => "notify",
      host        => "localhost",
      port        => "5222",
      handler     =>

      sub {
            my ( $rc, $p ) = @_;
	    print STDERR "Counter: ".$c++."\n";

            # you only get a packet in the callback once the main loop has started
            if ( $p ){
              my $e = $p->getElement();
              my $to = $e->getAttrib('to');
              $e->putAttrib('to', $e->getAttrib('from'));
              $e->putAttrib('from', $to);
              $rc->deliver( $p );
	      
	      $rc->stop() if $c == 51;
	    } else {
	      print STDERR "First time thru .... \n";
	      my $e = new Jabber::Judo::Element("presence");
	      my $ps = new Jabber::JAX::Packet($e);
              $rc->deliver( $ps );
	    }

          }
     );

$conn->start();


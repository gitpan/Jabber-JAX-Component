# Need to suppress warinings ?
BEGIN { $^W = 0; $| = 1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}
use Jabber::JAX::Component;
$loaded = 1;
print "ok 1\n";



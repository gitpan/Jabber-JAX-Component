use strict;

use Jabber::Judo::Element;

my $e = new Jabber::Judo::Element( "message" );
$e->putAttrib("to", "piers\@pxharding.dyndns.org");
$e->putAttrib("from", "echo\@pxharding.dyndns.org");
my $e1 = $e->addElement("body");
$e1->addCDATA("Hello World");
my $e2 = $e->addElement("abody");
$e2->addCDATA("Hello World");
print "Constructed Element: ".$e->toString()."\n";
$e2->setText("Goodbye World");
print "Modified Element: ".$e->toString()."\n";

print "\nGet children of e:\n";
foreach ($e->getChildren()){
  print "Child: ".$_->getName()." = ".$_->getCDATA()."\n";  
}

print "\nFind element <abody> of e : ".$e->findElement('abody')->toString()."\n";
print "\nFind element <xbody> of e ( does not exist ) :\n ";
 if ( my $x = $e->findElement('xbody')){
   print "<xbody> is: ".$x."\n";
   print "<xbody> is: ".$x->toString()."\n";
 };

print "\nGet children of e2:\n";
foreach ($e2->getChildren()){
  print "Child: ".$_->getName()." = ".$_->getCDATA()."\n";  
}

print "Get Attrib: ".$e->getAttrib("from")."\n";
print $e->delAttrib("from");
print "After attrib del: ".$e->toString()."\n";

$e->delElement("abody");
print "After Element del: ".$e->toString()."\n";

use Jabber::JAX::Packet;
my $p = new Jabber::JAX::Packet( $e );
print "Packet toString IS:". $p->toString()."\n";
my $e2 = $p->getElement();
print "After getElement on Packet: ".$e2->toString()."\n";

my $e3 = Jabber::Judo::Element::parseAtOnce("<message to='blah\@blah'><subject>The subject</subject><body> something in the body </body></message>");

print "from string to element to string: ".$e3->toString()."\n";

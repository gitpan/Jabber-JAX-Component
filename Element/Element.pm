package Jabber::Judo::Element;
use strict;

# Ensure that the build directory exists
BEGIN { `mkdir /tmp/_Inline` if ! -d '/tmp/_Inline' }

use vars qw($VERSION);
$VERSION = '0.01';

use Cwd qw(abs_path);                                                           

# Inline config for the build of the C++ components
#  requires libjax, libjudo, and libbedrock from the JECLs
#use Inline 'NOCLEAN';

use Inline 'CPP' => 'Config' =>
# force my header files to come first because they clash
#  badly with perls
                    'AUTO_INCLUDE' => [ undef,
		                       '#include <unistd.h>',
		                       '#include <gen_component.h>',
		                       ' extern "C" {','#include "EXTERN.h"',
		                       '#include "perl.h"',
		                       '#include "XSUB.h"',
		                       '#include "INLINE.h"',
		                       ' }'],
                    'CC' => 'g++3',
                    'LD' => 'g++3',
                    'DIRECTORY' => '/tmp/_Inline',
                    'INC' => '-I/usr/local/jax/include '. 
                             '-I/usr/local/include -I'.abs_path('..').' '. 
                             ' -I'.abs_path('.'),
                    'LIBS' => '-L/usr/local/jax/lib -lbedrock -ljudo -ljax '.
		              '-lresolv -lnsl -lpthread -lresolv '.
			      '-lnsl -lpthread',
                    'CCFLAGS' => '-DHAVE_CONFIG_H -D_REENTRANT '.
		                 '-D_POSIX_PTHREAD_SEMANTICS -D__USE_MALLOC',
		    ;

use Inline 'CPP';

# Config for Inline::MakeMaker
#use Inline 'CPP' => 'DATA',
#                     NAME => 'Jabber::Judo::Element',
#                     VERSION => '0.01';


=head1 NAME

Jabber::Judo::Element - Perl wrapper for the JECL Library judo::Element Object

=head1 SYNOPSIS

  use Jabber::Judo::Element;

  my $e = new Jabber::Judo::Element( "message" );
  $e->putAttrib("to", 'piers@jabber.org');
  $e->putAttrib("from", 'tester1@jabber.org');
  my $e2 = $e->addElement("body");
  $e2->addCDATA("Hello World!");
  print $e->toString()."\n";

=head1 DESCRIPTION

Jabber::Judo::Element is yet another perl implementation for writing 
Jabber components.  How it differs is that it is a wrapper for the 
high performance JECL libraries for writing components in C++.

Jabber::Judo::Element is the complement for the judo::Element C++ object
( see the judo.h header file for a description ).  It elmulates most ( not all )
object methods found here for the creation and manipulating XML packets.


=head2 The Methods

Discussion/Explaination of the methods.  As far as possible the Author has tried to emulate the judo::* API for XML node manipulation.  Some time this is not possible/practical because of the differences between perl and C++

=cut

=item new

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
 
  Create an element by passing the name of the tag.

=cut

# create a new judo::Element object and wrap a perl
#  object arround it
sub new {
  my $proto = shift;
  my $name = shift;
  die "MUST supply name to Element->new()"
     unless $name;
  my $class = ref($proto) || $proto;
  my $self = {
      ELEMENT => new_element( $name ),
      };
  die "Could not create a Element object " 
            unless $self->{ELEMENT};
  bless( $self, $class );
  return $self;
}


=item parseAtOnce

  use Jabber::Judo::Element;
  my $e = Jabber::Judo::Element::parseAtOnce( "<message to='blah' from='blah2'><body>Hello</body></message>" );
  print "The Element: ". $e->toString()."\n";
 
  Take a piece of XML as a string and turn it into a Judo::Element object.

=cut

# retrieve the name of the XML node
sub parseAtOnce {

  my $xml = shift;
  die "MUST pass xml string as argument "
     unless $xml;
  my $class = 'Jabber::Judo::Element';
  my $e = {
      ELEMENT => parse_at_once( $xml )
	};
  die "Could not create an Element object from string: $xml " 
              unless $e->{ELEMENT};
  bless( $e, $class );
  return $e;

}



=item getName

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  print "The tag name: ". $e->getName()."\n";
 
  Retrieve the name of an Element tag

=cut

# retrieve the name of the XML node
sub getName {
  my $self = shift;
  return  get_name( $self->{ELEMENT} );
}


=item getChildren

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  foreach ( $e->getChildren() ){
    print "The tag name: ".$_->getName()."\n";
  }
 
  Get a list of the children elements of this parent element

=cut

#  get the list of child elements
sub getChildren {
  my $self = shift;
  my @e = ();
  my $class = 'Jabber::Judo::Element';
  foreach ( get_children( $self->{ELEMENT} ) ){
    my $el = {
        ELEMENT => $_
	};
    bless( $el, $class );
    push(@e, $el);
  }
  return @e;
}


=item addCDATA

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  $e1->addCDATA("Hello World!");
 
  Add the CDATA value to an element - actually returns
  the just added CDATA value as well.

=cut

# Paste some cdata onto an element
sub addCDATA {
  my $self = shift;
  my $data = shift;
  return  add_cdata( $self->{ELEMENT}, $data );
}


=item setText

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  $e1->setText("Hello World!");
 
  Overwrite the CDATA value to an element.

=cut

# Paste some cdata into an element
sub setText {
  my $self = shift;
  my $data = shift;
  return set_text( $self->{ELEMENT}, $data );
}



=item getCDATA

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  $e1->addCDATA("Hello World!");
  print "the CDATA: ".$e1->getCDATA()."\n";
 
  Retrieve the CDATA value of an element.

=cut

# retrieve the cdata from an element
sub getCDATA {
  my $self = shift;
  return  get_cdata( $self->{ELEMENT} );
}


=item addElement

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
 
  Add an element as the next child node of the parent
  element.  Returns another Jabber::Judo::Element object.

=cut

# add a new element - return the new element
sub addElement {
  my $self = shift;
  my $name = shift;
  die "MUST supply name to addElement"
     unless $name;
  my $class = ref($self);
  my $e = {
      ELEMENT => add_element( $self->{ELEMENT}, $name )
	};
  die "Could not create a Element object: $name " 
              unless $e->{ELEMENT};
  bless( $e, $class );
  return $e;
}


=item findElement

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  my $x = $e->findElement("body");
 
  Find an element with a given tag name.  Returns 
  another Jabber::Judo::Element object.

=cut

# find an element - return it
sub findElement {
  my $self = shift;
  my $name = shift;
  my $class = ref($self);
  my $e = {
      ELEMENT => find_element( $self->{ELEMENT}, $name )
	};
  return undef unless $e->{ELEMENT};
  bless( $e, $class );
  return $e;
}


=item delElement

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  $e->delElement("body");
  print "Element gone: ".$e->toString()."\n";
 
  Delete a given child element from an element.

=cut

# delete an Element
sub delElement {
  my $self = shift;
  my $name = shift;
  die "MUST supply name to delElement"
     unless $name;
  del_element( $self->{ELEMENT}, $name );
}


=item isEmpty

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  if ( $e->isEmpty() ){
   ....
  }
 
  Check to see if a node is empty

=cut

# check if element node is empty
sub isEmpty {
  my $self = shift;
  return  empty_element( $self->{ELEMENT} );
}



=item toString

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  print "Stringified: ". $e->toString()."\n";
 
  Return a string representation of the XML node
  properly escaped.

=cut

# convert the element node to a string
sub toString {
  my $self = shift;
  return  to_string( $self->{ELEMENT} );
}



=item size

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e1 = $e->addElement( "body" );
  print "No. of children: ".$e->size()."\n";
 
  Returns the number of children that a given node has.

=cut

# retireve the number of children
sub size {
  my $self = shift;
  return  element_size( $self->{ELEMENT} );
}


# a hidden method for creating Jabber::JAX::Packet s with
sub _element {
  my $self = shift;
  return $self->{ELEMENT};
}



=item putAttrib

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e->putAttrib("to", "piers\@localhost");
 
  Set the value of an attribute

=cut

# set the value of an attribute
sub putAttrib {
  my $self = shift;
  my $name = shift;
  die "MUST supply name to putAttrib"
     unless $name;
  my $value = shift;
  put_attrib( $self->{ELEMENT}, $name, $value );
}


=item getAttrib

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e->putAttrib("to", "piers\@localhost");
  print "Attribute to: ".$e->getAttrib("to")."\n";
 
  Get the value of an attribute

=cut

# get the value of an attribute
sub getAttrib {
  my $self = shift;
  my $name = shift;
  die "MUST supply name to getAttrib"
     unless $name;
  return  get_attrib( $self->{ELEMENT}, $name );
}


=item cmpAttrib

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e->putAttrib("to", "piers\@localhost");
  if ( $e->getAttrib("to", "piers\@localhost") ){
    print "Attribute to: ".$e->getAttrib("to")."\n";
  }
 
  Compare/check the value of an attribute -
  returns true if correct

=cut

# compare/check the value of an attribute
sub cmpAttrib {
  my $self = shift;
  my $name = shift;
  die "MUST supply name to cmpAttrib"
     unless $name;
  my $value = shift;
  return cmp_attrib( $self->{ELEMENT}, $name, $value );
}


=item delAttrib

  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  my $e->putAttrib("to", "piers\@localhost");
  $e->delAttrib("to");
  print "Attributeless element: ".$e->toString()."\n";
 
  Delete a given attribute from an element.

=cut

# delete an attribute
sub delAttrib {
  my $self = shift;
  my $name = shift;
  die "MUST supply name to delAttrib"
     unless $name;
  del_attrib( $self->{ELEMENT}, $name );
}


=head1 VERSION

very new

=head1 AUTHOR

Piers Harding - but DizzyD ( author of JECL ) is the real star

=head1 SEE ALSO

Jabber::JAX::Packet, Jabber::JAX::Component, Jabber::JAX::MyRouterConnection

=cut


1;

__DATA__

__CPP__


using namespace std;
using namespace judo;

class MyElement: 
    public Element
{
public:
    MyElement();
    void   delElement(const std::string& name);
};


void MyElement::delElement(const string& name) {
    iterator it = begin();
    for (; it != end(); it++)
    {
	if (((*it)->getType() == Node::ntElement) && 
	    ((*it)->getName() == name))
	    break;
    }
    if (it != end()){
        Node *node = *it;
        _children.erase(it);
	delete(node);
    }
}


SV* new_element( SV* name ) {
  Element* e = new Element( SvPV(name,SvCUR(name)) );

  SV* obj_ref = newSViv(0);
  SV* obj = newSVrv(obj_ref, NULL);
  sv_setiv(obj, (IV)e);
  SvREADONLY_on(obj);
  return obj_ref;

} 


SV* parse_at_once(SV* xml_string) {

  Element* e = judo::ElementStream::parseAtOnce(SvPV(xml_string,SvCUR(xml_string)));

  SV* obj_ref = newSViv(0);
  SV* newobj = newSVrv(obj_ref, NULL);
  sv_setiv(newobj, (IV)e);
  SvREADONLY_on(newobj);
  return obj_ref;

}

 
SV* add_element(SV* obj, SV* name ) {
  
  Element* e = ((Element*) SvIV(SvRV(obj)))->addElement(SvPV(name,SvCUR(name)));

  SV* obj_ref = newSViv(0);
  SV* newobj = newSVrv(obj_ref, NULL);
  sv_setiv(newobj, (IV)e);
  SvREADONLY_on(newobj);
  return obj_ref;
       
}


void del_element(SV* obj, SV* name) {

  ((MyElement*) SvIV(SvRV(obj)))->delElement(SvPV(name,SvCUR(name)));

}


SV* get_name(SV* obj ) {

  std::string s = ((Element*) SvIV(SvRV(obj)))->getName();
  return newSVpv( s.data(), s.length() );

}


void get_children(SV* obj ) {

  Inline_Stack_Vars;

  Inline_Stack_Reset;
  Element::iterator e = ((Element*) SvIV(SvRV(obj)))->end();
  for ( Element::iterator b = ((Element*) SvIV(SvRV(obj)))->begin();
        b != e;
	b++ ){
    if ( ((Node*) *b)->getType() == judo::Node::ntElement) {
      SV* obj_ref = newSViv(0);
      SV* newobj = newSVrv(obj_ref, NULL);
      sv_setiv(newobj, (IV)((Element*) *b));
      SvREADONLY_on(newobj);
      Inline_Stack_Push(obj_ref);
    };
  };
  Inline_Stack_Done;

}


SV* get_cdata(SV* obj ) {

  std::string s = ((Element*) SvIV(SvRV(obj)))->getCDATA();
  return newSVpv( s.data(), s.length() );

}


SV* add_cdata(SV* obj, SV* data ) {

  CDATA* cdata = ((Element*) SvIV(SvRV(obj)))->addCDATA(SvPV(data,SvCUR(data)), SvCUR(data));
  std::string s = cdata->toString();
  return newSVpv( s.data(), s.length() );

}


SV* set_text(SV* obj, SV* data ) {

  CDATA* cdata = ((Element*) SvIV(SvRV(obj)))->addCDATA(" ", 1);
  cdata->setText(SvPV(data,SvCUR(data)), SvCUR(data));
  std::string s = cdata->toString();
  return newSVpv( s.data(), s.length() );

}



SV* to_string(SV* obj) {

  std::string s = ((Element*) SvIV(SvRV(obj)))->toString();
  return newSVpv( s.data(), s.length() );

}


void put_attrib(SV* obj, SV* name, SV* value) {

  ((Element*) SvIV(SvRV(obj)))->putAttrib(SvPV(name,SvCUR(name)), SvPV(value,SvCUR(value)));

}


SV* get_attrib(SV* obj, SV* name) {

  std::string s = ((Element*) SvIV(SvRV(obj)))->getAttrib(SvPV(name,SvCUR(name)));
  return newSVpv( s.data(), s.length() );

}


SV* cmp_attrib(SV* obj, SV* name, SV* value) {

  bool ret = ((Element*) SvIV(SvRV(obj)))->cmpAttrib(SvPV(name,SvCUR(name)),SvPV(value,SvCUR(value)));
  return newSViv( (int) ret );

}


SV* empty_element(SV* obj) {

  bool ret = ((Element*) SvIV(SvRV(obj)))->empty();
  return newSViv( (int) ret );

}


SV* element_size(SV* obj) {

  int sze = ((Element*) SvIV(SvRV(obj)))->size();
  return newSViv( sze );

}


void del_attrib(SV* obj, SV* name) {

  ((Element*) SvIV(SvRV(obj)))->delAttrib(SvPV(name,SvCUR(name)));

}


SV* find_element(SV* obj, SV* name ) {

  Element* e = ((Element*) SvIV(SvRV(obj)))->findElement(SvPV(name,SvCUR(name)));

  if ( e != NULL ){
    SV* obj_ref = newSViv(0);
    SV* newobj = newSVrv(obj_ref, NULL);
    sv_setiv(newobj, (IV)e);
    SvREADONLY_on(newobj);
    return obj_ref;
  } else {
    return newSViv( 0 );
  }

}



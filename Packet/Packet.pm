package Jabber::JAX::Packet;
use strict;

# Ensure that the build directory exists
BEGIN { `mkdir /tmp/_Inline` if ! -d '/tmp/_Inline' }


use vars qw($VERSION);
$VERSION = '0.01';

use Cwd qw(abs_path);                                                           

# Inline config for the build of the C++ components
#  requires libjax, libjudo, and libbedrock from the JECLs

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
		              '-lpthread -lresolv ',
#                    'CCFLAGS' => '-DHAVE_CONFIG_H -D_REENTRANT '.
#		                 '-D_POSIX_PTHREAD_SEMANTICS -D__USE_MALLOC',
		    ;

use Inline 'CPP';

# Config for Inline::MakeMaker
#use Inline 'CPP' => 'DATA',
#                     NAME => 'Jabber::JAX::Packet',
#                     VERSION => '0.01';


=head1 NAME

Jabber::JAX::Packet - Perl wrapper for the JECL Library creates a jax::Packet C++ object that is either received as the second argument of the Component callback handler ( see Jabber::JAX::Component ), or is created for outbound delivery of an XML packet.


=head1 SYNOPSIS

  use Jabber::JAX::Packet;
  use Jabber::Judo::Element;
  my $e = new Jabber::Judo::Element( "message" );
  $e->putAttrib("to", "piers\@localhost");
  $e->putAttrib("from", "echo\@localhost");
  my $e1 = $e->addElement("body");
  $e1->addCDATA("Hello World");
  my $p = new Jabber::JAX::Packet( $e );

  # ... in the context of the  callback subroutine
  $rc->deliver( $p );
 

=head1 DESCRIPTION

Jabber::JAX::Component is yet another perl implementation for writing 
Jabber components.  How it differs is that it is a wrapper for the 
high performance JECL libraries for writing components in C++.

Jabber::JAX::Packet is the complement for the jax::Packet C++ object
( see the jax.h header file for a description ).  It basically only has one method and that is $p->getElement() for retrieving the Jabber::Judo::Element ( judo::Element ) inside.  The Element object is the unit that has all the XML node manipulation methods/tools ( see perldoc Jabber::Judo::Element ).

=head1 VERSION

very new

=head1 AUTHOR

Piers Harding - but DizzyD ( author of JECL ) is the real star

=head1 SEE ALSO

Jabber::JAX::Packet, Jabber::JAX::Component, Jabber::JAX::MyRouterConnection, Jabber::Judo::Element

=cut



sub new {
    my $proto = shift;
    my $element = shift;
    die "Need a Jabber::Judo::Element as an arguement"
      unless ref($element) eq 'Jabber::Judo::Element';
    my $class = ref($proto) || $proto;
    my $self = {
        PACKET => new_packet( $element->_element() ),
	};
    die "Could not create a Packet object " 
              unless $self->{PACKET};
    bless( $self, $class );
    return $self;
}


sub getElement {
  my $self = shift;
  my $class = 'Jabber::Judo::Element';
  my $e = {
      ELEMENT => get_element( $self->{PACKET} )
	};
  die "Could not create a Element object " 
              unless $e->{ELEMENT};
  bless( $e, $class );
  return $e;
}


sub toString {
  my $self = shift;
  return  to_string( $self->{PACKET} );
}


sub _packet {
  my $self = shift;
  return $self->{PACKET};
}


1;

__DATA__

__CPP__


using namespace std;
using namespace jax;
using namespace judo;


SV* new_packet( SV* element ) {
  Packet* p = new Packet( ((Element*) SvIV(SvRV(element))) );

  SV* obj_ref = newSViv(0);
  SV* obj = newSVrv(obj_ref, NULL);
  sv_setiv(obj, (IV)p);
  SvREADONLY_on(obj);
  return obj_ref;

}


SV* get_element(SV* obj ) {

  Element* e = ((Packet*) SvIV(SvRV(obj)))->getElement();

  SV* obj_ref = newSViv(0);
  SV* newobj = newSVrv(obj_ref, NULL);
  sv_setiv(newobj, (IV)e);
  SvREADONLY_on(newobj);
  return obj_ref;

}


SV* to_string(SV* obj) {

  std::string s = ((Packet*) SvIV(SvRV(obj)))->toString();
  return newSVpv( s.data(), s.length() );

}


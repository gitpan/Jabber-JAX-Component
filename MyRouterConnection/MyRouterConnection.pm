package Jabber::JAX::MyRouterConnection;
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
                    'DIRECTORY' => '/tmp/_Inline',
                    'INC' => '-I/usr/local/include -I'.abs_path('..').' '. 
                             '-I/usr/local/include -I'.abs_path('.'),
                    'LIBS' => '-L'.abs_path('..').' -lbedrock -ljudo -ljax '.
                              '-L'.abs_path('.').' -lbedrock -ljudo -ljax '.
		              '-L/usr/local/lib -lbedrock -ljudo -ljax '.
		              '-lresolv -lnsl -lpthread -lresolv '.
			      '-lnsl -lpthread',
                    'CCFLAGS' => '-DHAVE_CONFIG_H -D_REENTRANT '.
		                 '-D_POSIX_PTHREAD_SEMANTICS -D__USE_MALLOC',
		    ;

use Inline 'CPP';

# Config for Inline::MakeMaker
#use Inline 'CPP' => 'DATA',
#                     NAME => 'Jabber::JAX::MyRouterConnection',
#                     VERSION => '0.01';


=head1 NAME

Jabber::JAX::MyRouterConnection - Perl wrapper for the JECL Library

=head1 SYNOPSIS

See Jabber::JAX::Component .

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
              #-----------------------------------------------
              #-----------------------------------------------
	      #
	      #  The subroutine is passed a reference to a
	      #  Jabber::JAX::MyRouterConnection object
	      #  This provides a single method - $rc->deliver( $p )
	      #  to facilitate delivery of outbound packets
	      #
              #-----------------------------------------------
              #-----------------------------------------------
              $rc->deliver( $p );

            }
       );
 
  $c->start();


=head1 DESCRIPTION

Jabber::JAX::Component is yet another perl implementation for writing 
Jabber components.  How it differs is that it is a wrapper for the 
high performance JECL libraries for writing components in C++.

Jabber::JAX::MyRouterConnection is a helper class that exposes the JECL C++ library function for delivering outbound packets ( Jabber::JAX::Packet )
( see the jax.h, judo.h, bedrock.h header files for a description ).  See above example for usage - note YOU DO NOT CREATE THIS FUNCTION YOURSELF - the callback handler is passed a reference to it.

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


sub deliver {
  my $self = shift;
  my $packet = shift->_packet();
  return punt( $self->{ROUTER}, $packet );
}



1;

__DATA__

__CPP__


using namespace std;
using namespace jax;
using namespace judo;


SV* to_string(SV* obj) {

  std::string s = ((Packet*) SvIV(SvRV(obj)))->toString();
  return newSVpv( s.data(), s.length() );

}


SV* punt(SV* obj, SV* pkt) {

  ((MyRouterConnection*) SvIV(SvRV(obj)))->deliver( ((Packet*) SvIV(SvRV(pkt))) );
  return newSViv(1);

}


package Jabber::JAX::Client;
use strict;

# Ensure that the build directory exists
BEGIN { `mkdir /tmp/_Inline` if ! -d '/tmp/_Inline' }

use vars qw($VERSION $DEBUG);
$VERSION = '0.01';
$DEBUG = undef;

use Cwd qw(abs_path); 
use Jabber::Judo::Element;
use Jabber::JAX::Packet;


# Inline config for the build of the C++ components
#  requires libjax, libjudo, and libbedrock from the JECLs
use Inline 'CPP' => 'Config' =>
# force my header files to come first because they clash
#  badly with perls
                    'AUTO_INCLUDE' => [ undef,
                                       '#include <unistd.h>',
                                       '#include <gen_client.h>',
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
#use Inline C=> 'DATA',
#                NAME => 'Jabber::JAX::Client',
#                VERSION => '0.01';


=head1 NAME

Jabber::JAX::Client - Perl wrapper for the Jabber JECL Library creates the Jabber Client Connection Object

=head1 SYNOPSIS

  use Jabber::JAX::Client;
 
  my $c = new Jabber::JAX::Client(
        user        => "blah\@blah.org",
        passwd      => "mysecret",
        host        => "localhost",
        port        => "5222",
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


=head1 DESCRIPTION

Jabber::JAX::Client is yet another perl implementation for writing 
Jabber components.  How it differs is that it is a wrapper for the 
high performance JECL libraries for writing components in C++.

Jabber::JAX::Client is the complement for the jax::RouterConnection C++ object
( see the jax.h header file for a description ).  It creates a basic connection object for a client to a jaber server with a thread pool ( currently 10 ), and provides the framework for embedding a perl callback subroutine to handle each incoming packet.  See the gen_client.h header file for more details.

To run this you should use perl 5.6.x ( the standard one supplied with RH 7.1 works ) - what ever one you use it MUST NOT be compiled with threads ( no -Dusethread -Duseithreads ) - check perl -V, and you need to get the JECL libraries from http://jabber.tigris.org ( check them out of CVS instead of downloading the tgz files ).  The only catch with the libraries are the dependencies ( explained within the library README doco ) - this requires the g++ >= 3.0.x.  At the time of writting this can be obtained from http://www.redhat.com in the RH 7.2 beta download section ( yay - GO RedHat ! ).


=head1 PROGRAMMING

Further to the SYNOPSIS above - the basic structure for programming with these perl packages is as follows:
The Jabber::JAX::Client object takes a subroutine reference for the parameter 'handler'.  This subroutine is then called on receipt of every packet by the Jabber client, and passed two arguements ( well three really  - but the last - the stringified xml is temporary until the judo::Element object is finalised ).
The First argument is $rc - a reference to the RouterConnection ( Jabber::JAX::Client ).  It has only two methods that you should use and they are deliver which is passed a Jabber::JAX::Packet object, for delivery, and stop which shutdowns the Client connection.
The second argument is $p a reference to the current inbound packet ( Jabber::JAX::Packet ). Use the $p->getElement() method to return a Jabber::Judo::Element object for easy manipulation of the XML packet.

There is currently no way to register a user with this library, so that will have to be achieved with another tool ( client, or library ) prior to running your scripts.


=head1 VERSION

very new

=head1 AUTHOR

Piers Harding - but DizzyD ( author of JECL ) is the real star

=head1 SEE ALSO

Jabber::JAX::Packet, Jabber::JAX::Client, Jabber::JAX::Component, Jabber::Judo::Element

=cut



# Create a component profile
#  passing in all the connection information
# and the name of the callback routine for handling the packet
sub new {

    my $proto = shift;
    my $class = ref($proto) || $proto;
    
    my $self = {
	host        => "localhost",
	port        => "5222",
	@_
	};

    if (exists $self->{server}){
      if ( $self->{server} =~ /:/ ){
        ( $self->{host}, $self->{port} ) =
           split( /:/, $self->{server});
      } else {
        $self->{host} = $self->{server};
	$self->{port} = '5222';
      }
    }

    die "must supply 'user' parameter to Jabber::JAX::Client"
        unless exists $self->{user};
    die "must supply 'passwd' parameter to Jabber::JAX::Client"
        unless exists $self->{passwd};
    die "must supply 'handler' parameter to Jabber::JAX::Client"
        unless exists $self->{handler};

# create the object and return it
    bless ($self, $class);
    return $self;

}


# This calls into the JECL libraries - sets up the component
# to run and never returns
sub start {

  my $self = shift;

  # we never come back from here
  runClient(   $self->{user}, 
               $self->{passwd}, 
               $self->{host}, 
	       $self->{port}, 
	       "Jabber::JAX::Client::ClientHandler",
	       $self);

}


# Wrapper for the callback subroutine that the user passes
sub ClientHandler {

  my $self =  shift;
  my $router = shift;
  my $packet = shift if scalar @_;
  my $xml = shift if scalar @_;

  # create a Router object to pass for access to the 
  #  deliver function
  my $class = 'Jabber::JAX::Client';
  my $rc = {
	'ROUTER'   => $router
	};
  bless ($rc, $class);

  # create a Packet object to give access to the 
  #  incoming xml packet
  my $p = "";
  if ( $packet ) {
    my $class = 'Jabber::JAX::Packet';
     $p = {
	'PACKET'   => $packet
	};
    bless ($p, $class);
  }

  # Call the subroutine reference passing
  #  the Router, Packet and the stringified XML ( not really necessary )
  my @result = &{$self->{handler}}( $rc, $p, $xml );

  return @result;

}



sub deliver {
  my $self = shift;
  my $packet = shift;
  debug("DBUG: deliver - ".$packet->toString());
  $packet = $packet->_packet();
  return punt( $self->{ROUTER}, $packet );
}



sub stop {
  my $self = shift;
  return client_stop( $self->{ROUTER} );
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

sub debug{

  print STDERR join(" ",scalar localtime(), @_, "\n") if $DEBUG;

}


1;

__DATA__

__CPP__


using namespace std;


int runClient(char* uid,
                 char* sec,
		 char* host,
		 int   prt,
		 char* pfunc,
		 SV* myself)
{
    string       user         = uid;
    string       secret       = sec;
    bool         outgoing     = true;

    string       jabberd_ip   = host;
    unsigned int jabberd_port = prt;

    string       perl_func    = pfunc;
    void*        my_self      = myself;

    int retval;

    cerr << "Starting Client connection..."   <<endl;
    cerr << "\tUser      ID : " << user <<endl;
    cerr << "\tJabberd IP   : " << jabberd_ip << endl;
    cerr << "\tJabberd Port : " << jabberd_port << endl << endl;

    ClientController cc(user, secret, jabberd_ip, 
                        jabberd_port, outgoing,
			perl_func, my_self);

    bedrock::Application::start();

}



// Constructor
ClientController::ClientController(const std::string& serviceid, 
			       const std::string& password, 
			       const std::string& hostname, 
			       unsigned int port, bool outgoing_dir,
                               const std::string& perl_func,
                               void* my_self)
    : _id(serviceid), _password(password), _hostname(hostname),
//      _port(port), _tpool(1), _watcher(_tpool, 10),
      _port(port), _tpool(1), _watcher(10),
      _router(_watcher, *this, outgoing_dir, 0),
      _perl_func(perl_func),
      _my_self(my_self)
{
    // Create an address struct, passing the hostname we want to
    // connect to, a standard SRV identifier, and a default port
    // to use (in case the SRV lookup doesn't get us a port)
    bedrock::net::Address addr(_hostname, "_jabber._tcp", _port);

    // Start the router connection
    _router.connect(_id, _password, addr);
}



void ClientController::onRouterPacket(jax::Packet* packet)
{

    // Generic packet handler
    //  Call registered perl subroutine
    //  Test for a deliver/follow on action and return

    int result;
    SV* res;
    std::string xml;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);

    // pointer to the calling object instance
    XPUSHs((SV*)_my_self);

    // Pointer to the router instance to be plugged into
    //  an object for calling use
    SV* obj_ref = newSViv(0);
    SV* obj = newSVrv(obj_ref, NULL);
    sv_setiv(obj, (IV) ((MyClientConnection*)&_router));
    SvREADONLY_on(obj);
    XPUSHs((SV*)obj_ref);

    // Pointer to the current incoming packet
    SV* packet_ref = newSViv(0);
    SV* packet_obj = newSVrv(packet_ref, NULL);
    sv_setiv(packet_obj, (IV) packet);
    SvREADONLY_on(packet_obj);
    XPUSHs((SV*)packet_ref);

    // scalar of the XML to string
    xml = packet->toString();
    XPUSHs(sv_2mortal(newSVpv( xml.data(),
			      xml.length() )));
    PUTBACK;
    result = perl_call_pv(_perl_func.data(), G_ARRAY | G_EVAL );

    if(SvTRUE(ERRSV)) fprintf(stderr, "perl call errored: %s", SvPV(ERRSV,PL_na));
    SPAGAIN;
    if ( result > 0 ){
      res = POPs;
    };
    PUTBACK;
    FREETMPS;
    pop_scope();  // is the part of LEAVE that we want

}



void MyClientConnection::onDocumentStart(judo::Element* elem)
{
    // cerr << "onDocumentStart The element: " << elem->toString() << endl;
    judo::Element iq("iq");
    iq.putAttrib("type","get");
    _handshake_id = elem->getAttrib("id");
    judo::Element* query = iq.addElement("query");
    query->putAttrib("xmlns","jabber:iq:auth");
    judo::Element* username = query->addElement("username");
    const std::string& name = _name.substr(0, _name.find_first_of("@"));
    username->addCDATA(name.c_str(),name.size());

    _socket->write(iq.toString());

    delete elem;
}


void MyClientConnection::onElement(judo::Element* elem)
{
    // If we are not yet connected, we should receive a handshake packet.
    // If we are the accepting socket, we need to validate the packet,
    // and if we are the connecting socket we receive an empty handshake
    // if the other end considers us valid.

    // cerr << "onElement The element: " << elem->toString() << endl;
    
    if (_state != Connecting)
    {
        _state_lock.lock();
    }

    if (_state == Connected)
    {
       // cerr << "onElement - state connected " << endl;
        _state_lock.unlock();
        _listener.onRouterPacket(Packet::create(elem));
    }
    else 
    {
        assert(_state == Connecting);
	// cerr << "onElement - state connecting " << endl;

	// I should only get iq's here as I am logging in - the
	//  iq:auth packet was sent in onDocumentStart
        if (elem->getName() == "iq")
        {
	    // is this a result type
            if (elem->getAttrib("type") == "result")
	    {
	       // cerr << "onElement I got a iq result " << endl;
		// get the first child element and test to see if it is 
		// in the iq:auth namespace
	        if (elem->empty() == false){
	            judo::Element::iterator first = elem->begin();
	           // cerr << "onElement - going to pick up the query" << endl;
                    if ( ((judo::Element*)(*first))->getAttrib("xmlns") == "jabber:iq:auth" )
                    {
	               // cerr << "onElement - The first child has an iq:auth namespace" << endl;
	            // this must have a username and a digest or password
	            //    element - what do I do if it doesnt?
	                if ( ((judo::Element*)(*first))->findElement("username") )
                        {
                        // this packet tells me what the user login options are
                        // I could choose to use plaintext or digest authentication here
                           // cerr << "onElement it was the login options " << endl;
                            judo::Element iq("iq");
                            iq.putAttrib("type","set");
                            judo::Element* query = iq.addElement("query");
                            query->putAttrib("xmlns","jabber:iq:auth");
                            judo::Element* username = query->addElement("username");
                            const std::string& name = _name.substr(0, _name.find_first_of("@"));
                            username->addCDATA(name.c_str(),name.size());
                            judo::Element* digest = query->addElement("digest");
                            bedrock::SHAHasher hasher;
                            hasher.hash(_handshake_id);
                            hasher.hash(_secret);
                            const std::string& p = hasher.toString();
                            digest->addCDATA(p.c_str(), p.size());
                            judo::Element* resource = query->addElement("resource");
                            const std::string& res = _name.substr(_name.find_first_of("/")+1,_name.size());
                            resource->addCDATA(name.c_str(),name.size());
                            _socket->write(iq.toString());
	                   // cerr << "onElement sending element: " << iq.toString() << endl;
	                }
	            }
	            else 
	            {
                        judo::Element error("stream:error");
                        error.addCDATA("Wrong iq namespace", strlen("Wrong iq namespace"));
        	        _socket->write(error.toString());
        	        _socket->close();
        	        _state_lock.unlock();
        	        _listener.onRouterError();
	            }
	        }
		else
		{
                   // cerr << "onElement it wasnt the login options " << endl;
                    if ( elem->getAttrib("id") == "pthsock_client_auth_ID" )
	            {
                       // cerr << "onElement - we have logged in - sending presence " << endl;
                        cerr << "onElement - we have logged in " << endl;

			((ClientController*) &_listener)->onCallBack();

    	                // judo::Element presence("presence");
                        //_socket->write(presence.toString());
                        _state = Connected;
                        _state_lock.unlock();
                        _listener.onRouterConnected();
                       // cerr << "onElement - passed the set router listener connected " << endl;
                    }
                    else
                    {
                       // cerr << "onElement error - we didnt get the empty result login conf " << endl;
                        judo::Element error("stream:error");
                        error.addCDATA("Invalid Login", strlen("Invalid Login"));
                        _socket->write(error.toString());
                        _socket->close();
                        _state_lock.unlock();
                        _listener.onRouterError();
	            }
		}
	    }
	    else if (elem->getAttrib("type") == "error")
	    {
                   // cerr << "onElement error - a login failure  " << endl;
                    judo::Element error("stream:error");
                    error.addCDATA("Invalid Login", strlen("Invalid Login"));
	            _socket->write(error.toString());
	            _socket->close();
	            _state_lock.unlock();
	            _listener.onRouterError();
	    }
	   
        }
        delete elem;
    }
}

void ClientController::onCallBack()
{

    //  Call registered perl subroutine
    //  Test for a deliver/follow on action and return
    int result;
    SV* res;
    std::string xml;
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    // pointer to the calling object instance
    XPUSHs((SV*)_my_self);
    // Pointer to the router instance to be plugged into
    //  an object for calling use
    SV* obj_ref = newSViv(0);
    SV* obj = newSVrv(obj_ref, NULL);
    sv_setiv(obj, (IV) ((MyClientConnection*)&_router));
    SvREADONLY_on(obj);
    XPUSHs((SV*)obj_ref);
    PUTBACK;
    result = perl_call_pv(_perl_func.data(), G_ARRAY | G_EVAL );
    if(SvTRUE(ERRSV)) fprintf(stderr, "perl call errored: %s", SvPV(ERRSV,PL_na));
    SPAGAIN;
    if ( result > 0 ){
      res = POPs;
    };
    PUTBACK;
    FREETMPS;
    pop_scope();  // is the part of LEAVE that we want

}


void MyClientConnection::onConnected(bedrock::net::Socket *sock)
{
    bedrock::MutexProxy mp(_state_lock);
    _socket->resumeRead();

    // We want to send the stream header now. 
    judo::Element elem("stream:stream");
    elem.putAttrib("xmlns:stream", "http://etherx.jabber.org/streams");
    elem.putAttrib("xmlns", "jabber:client");
    std::string name = _name.substr(_name.find_first_of("@")+1);
    name = name.substr(0,name.find_first_of("/"));
    elem.putAttrib("to", name);
    _socket->write(elem.toStringEx().c_str());
    //cerr << "onConnected Just put thru the XML headers: " << elem.toStringEx().c_str() << endl;
    //cerr << "onConnected hostname: " << _listener.myHostname() << endl;
}

// Router event callbacks
void ClientController::onRouterConnected()
{
    cerr << "Client is now connected." << endl;
}

void ClientController::onRouterDisconnected()
{
    cerr << "Client is now disconnected." << endl;
    bedrock::Application::stop(1, "Client connection lost");
}

void ClientController::onRouterError()
{
    cerr << "Client error occurred." << endl;
    _router.disconnect();
}




SV* to_string(SV* obj) {

  std::string s = ((Packet*) SvIV(SvRV(obj)))->toString();
  return newSVpv( s.data(), s.length() );

}


SV* punt(SV* obj, SV* pkt) {

  ((MyClientConnection*) SvIV(SvRV(obj)))->deliver( ((Packet*) SvIV(SvRV(pkt))) );
  return newSViv(1);

}



SV* client_stop(SV* obj) {

  // stop it!
  ((MyClientConnection*) SvIV(SvRV(obj)))->disconnect();
  return newSViv(1);

}



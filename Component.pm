package Jabber::JAX::Component;
use strict;

# Ensure that the build directory exists
BEGIN { `mkdir /tmp/_Inline` if ! -d '/tmp/_Inline' }

use vars qw($VERSION);
$VERSION = '0.10';

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
#                    'LIBS' => '-L/usr/local/jax/lib -lbedrock -ljudo -ljax '.
#		              '-lresolv -lnsl -lpthread -lresolv '.
#			      '-lnsl -lpthread',
#                    'CCFLAGS' => '-DHAVE_CONFIG_H -D_REENTRANT '.
#		                 '-D_POSIX_PTHREAD_SEMANTICS -D__USE_MALLOC',

# Config for Inline::MakeMaker
#use Inline C=> 'DATA',
#                NAME => 'Jabber::JAX::Component',
#                VERSION => '0.02';


=head1 NAME

Jabber::JAX::Component - Perl wrapper for the Jabber JECL Library creates the Jabber Compoent Connection Object

=head1 SYNOPSIS

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

            },

        inithandler     =>
 
        sub {
               print STDERR "Hi - I've Started ...\n";
            },

        stophandler     =>
 
        sub {
               print STDERR "Hi - I'm Stopping ...\n";
            },
       );
 
  $c->start();


=head1 DESCRIPTION

Jabber::JAX::Component is yet another perl implementation for writing 
Jabber components.  How it differs is that it is a wrapper for the 
high performance JECL libraries for writing components in C++.

Jabber::JAX::Component is the complement for the jax::RouterConnection C++ object
( see the jax.h header file for a description ).  It creates a basic connection object for a component to a jaber server with a thread pool ( currently 10 ), and provides the framework for embedding a perl callback subroutine to handle each incoming packet.  See the gen_component.h header file for more details.

To run this you should use perl 5.6.x ( the standard one supplied with RH 7.1 works ) - what ever one you use it MUST NOT be compiled with threads ( no -Dusethread -Duseithreads ) - check perl -V, and you need to get the JECL libraries from http://jabber.tigris.org ( check them out of CVS instead of downloading the tgz files ).  The only catch with the libraries are the dependencies ( explained within the library README doco ) - this requires the g++ >= 3.0.x.  At the time of writting this can be obtained from http://www.redhat.com in the RH 7.2 beta download section ( yay - GO RedHat ! ).


=head1 PROGRAMMING

Further to the SYNOPSIS above - the basic structure for programming with these perl packages is as follows:
The Jabber::JAX::Component object takes a subroutine reference for the parameter 'handler'.  This subroutine is then called on receipt of every packet by the Jabber component, and passed two arguements ( well three really  - but the last - the stringified xml is temporary until the judo::Element object is finalised ).
The First argument is $rc - a reference to the RouterConnection ( Jabber::JAX::Component ).  It has only two methods that you should use and that is deliver, which is passed a Jabber::JAX::Packet object, for delivery, and stop which will shutdown the component.
The second argument is $p a reference to the current inbound packet ( Jabber::JAX::Packet ). Use the $p->getElement() method to return a Jabber::Judo::Element object for easy manipulation of the XML packet.

Don't forget to create the corresponding entry int the jabber.xml config file such as:
 
  <service id='echocomp'>
    <accept>
      <ip/>
      <port>7000</port>
      <secret>mysecret</secret>
    </accept>
  </service>


=head1 VERSION

very new

=head1 AUTHOR

Piers Harding - but DizzyD ( author of JECL ) is the real star

=head1 SEE ALSO

Jabber::JAX::Packet, Jabber::JAX::Component, Jabber::JAX::Client, Jabber::Judo::Element

=cut



# Create a component profile
#  passing in all the connection information
# and the name of the callback routine for handling the packet
sub new {

    my $proto = shift;
    my $class = ref($proto) || $proto;
    
    my $self = {
	component   => "echocomp",
	secret      => "secret",
	host        => "localhost",
	port        => "7000",
	@_
	};

    if (exists $self->{server}){
      if ( $self->{server} =~ /:/ ){
        ( $self->{host}, $self->{port} ) =
           split( /:/, $self->{server});
      } else {
        $self->{host} = $self->{server};
	$self->{port} = '7000'; # ? not sure what this should be
      }
    }

    die "must supply 'component' parameter to Jabber::JAX::Component"
        unless exists $self->{component};
    die "must supply 'secret' parameter to Jabber::JAX::Component"
        unless exists $self->{secret};
    die "must supply 'host' or 'server' parameter".
        " to Jabber::JAX::Component"
        unless exists $self->{host};
    die "must supply 'port' or 'server' parameter".
        " to Jabber::JAX::Component"
        unless exists $self->{port};
    die "must supply 'handler' parameter to Jabber::JAX::Component"
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
  runComponent($self->{component}, 
               $self->{secret}, 
               $self->{host}, 
	       $self->{port}, 
	       "Jabber::JAX::Component::ComponentHandler",
	       "Jabber::JAX::Component::InitHandler",
	       "Jabber::JAX::Component::StopHandler",
	       $self);

}


# Wrapper for the Stop callback subroutine that the user passes
sub StopHandler {

  my $self =  shift;
  my $router = shift;


  # dont bother if we dont have one
  return () unless exists $self->{'stophandler'};

  # create a Router object to pass for access to the 
  #  deliver function
  my $class = 'Jabber::JAX::Component';
  my $rc = {
	'ROUTER'   => $router
	};
  bless ($rc, $class);

  # Call the subroutine reference passing
  #  the Router, Packet and the stringified XML ( not really necessary )
  my @result = &{$self->{'stophandler'}}( $rc );

  return @result;

}


# Wrapper for the init callback subroutine that the user passes
sub InitHandler {

  my $self =  shift;
  my $router = shift;

  # dont bother if we dont have one
  return () unless exists $self->{'inithandler'};

  # create a Router object to pass for access to the 
  #  deliver function
  my $class = 'Jabber::JAX::Component';
  my $rc = {
	'ROUTER'   => $router
	};
  bless ($rc, $class);

  # Call the subroutine reference passing
  #  the Router, Packet and the stringified XML ( not really necessary )
  my @result = &{$self->{'inithandler'}}( $rc );

  return @result;

}


# Wrapper for the callback subroutine that the user passes
sub ComponentHandler {

  my $self =  shift;
  my $router = shift;
  my $packet = shift;
  my $xml = shift;

  # create a Router object to pass for access to the 
  #  deliver function
  my $class = 'Jabber::JAX::Component';
  my $rc = {
	'ROUTER'   => $router
	};
  bless ($rc, $class);

  # create a Packet object to give access to the 
  #  incoming xml packet
  my $class = 'Jabber::JAX::Packet';
  my $p = {
	'PACKET'   => $packet
	};
  bless ($p, $class);

  # Call the subroutine reference passing
  #  the Router, Packet and the stringified XML ( not really necessary )
  my @result = &{$self->{'handler'}}( $rc, $p, $xml );

  return @result;

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
  my $packet = shift;
#  warn " SENDING: ".$packet->toString()."\n\n";
  my $packet = $packet->_packet();
  return punt( $self->{ROUTER}, $packet );
}


sub stop {
  my $self = shift;
  return component_stop( $self->{ROUTER} );
}


sub getNextID {
  my $self = shift;
  return get_next_id( $self->{ROUTER} );
}


1;

__DATA__

__CPP__


using namespace std;

using namespace gencomp;

// Constructor
Controller::Controller()
    : _timer(1)
{}


Controller::~Controller()
{}


void Controller::setPerlFunc(const std::string& perl_func, const std::string& init_pfunc, const std::string& stop_pfunc, void* my_self)
{
   //cerr << "Setting the Perl values ...." << endl;
   _perl_func  = perl_func;
   _init_pfunc = init_pfunc;
   _stop_pfunc = stop_pfunc;
   _my_self = my_self;
}


void Controller::init(judo::Element* e)
{

    _tpool   = new bedrock::ThreadPool(2);
    _tkey    = _tpool->getNextThreadID();
    _watcher = new bedrock::net::SocketWatcher(2);

    //cerr << "Component element passed to init:" << e->toString() << endl;
    _jabberd_ip       = e->findElement("jax:component:host")->getCDATA();
    _jabberd_port     = atoi(e->findElement("jax:component:port")->getCDATA().c_str());
    _component_id     = e->findElement("jax:component:name")->getCDATA();
    _component_secret = e->findElement("jax:component:secret")->getCDATA();
    
    _router = new MyRouterConnection(*_watcher, *this, true, _tkey);

    establishRouterConnection(0);


}


string Controller::getNextID()
{
    char buf[64];
    snprintf(buf, 64, "A%d", _pending_counter++);
    return string(buf);
}


void Controller::establishRouterConnection(int retrycount)
{
    if (retrycount > 3)
    {
	jax::Component::stop(-1, "Unable to establish router connection.");
    }

    try
    {
	bedrock::net::Address addr(_jabberd_ip, string(""), _jabberd_port);
	_router->connect(_component_id, _component_secret, addr);
    }
    catch (MyRouterConnection::exception::SocketError& e)
    {
	_timer.schedule(5, _tpool, _tkey,
			bedrock::callback::wrap(this,
				       &Controller::establishRouterConnection,
						retrycount+1), 1);
    }
    // cerr << "establish: Connected" << endl;
}


// Router event callbacks
void Controller::onRouterConnected()
{
    cerr << "[jax::RouterConnection] Router is now connected." << endl;
    int result;
    SV* res;

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
    sv_setiv(obj, (IV) this);
    SvREADONLY_on(obj);
    XPUSHs((SV*)obj_ref);
    PUTBACK;

    result = perl_call_pv(_init_pfunc.data(), G_ARRAY | G_EVAL );

    if(SvTRUE(ERRSV)) fprintf(stderr, "perl call errored: %s", SvPV(ERRSV,PL_na));
    SPAGAIN;
    if ( result > 0 ){
      res = POPs;
    };
    PUTBACK;
    FREETMPS;
    pop_scope();  // is the part of LEAVE that we want
}

void Controller::onRouterDisconnected()
{
    sleep(2);
    cerr << "Router disconnected - retry ...." << endl;
    establishRouterConnection(0);
}

void Controller::onRouterError()
{
    cerr << "[jax::RouterConnection] Router error occurred." << endl;
    _router->disconnect();
}


void Controller::disconnect()
{
    int result;
    SV* res;

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
    sv_setiv(obj, (IV) this);
    SvREADONLY_on(obj);
    XPUSHs((SV*)obj_ref);
    PUTBACK;

    result = perl_call_pv(_stop_pfunc.data(), G_ARRAY | G_EVAL );

    if(SvTRUE(ERRSV)) fprintf(stderr, "perl call errored: %s", SvPV(ERRSV,PL_na));
    SPAGAIN;
    if ( result > 0 ){
      res = POPs;
    };
    PUTBACK;
    FREETMPS;
    pop_scope();  // is the part of LEAVE that we want
    sleep(2);
    Application::stop(0, "Shutting Down ....");
    Application::exit(0, "Exiting gracefully ....");
}


void Controller::onRouterPacket(jax::Packet* p)
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
    sv_setiv(obj, (IV) this);
    SvREADONLY_on(obj);
    XPUSHs((SV*)obj_ref);

    // Pointer to the current incoming packet
    SV* packet_ref = newSViv(0);
    SV* packet_obj = newSVrv(packet_ref, NULL);
    sv_setiv(packet_obj, (IV) p);
    SvREADONLY_on(packet_obj);
    XPUSHs((SV*)packet_ref);

    // scalar of the XML to string
    xml = p->toString();
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


SV* to_string(SV* obj) {

  std::string s = ((Packet*) SvIV(SvRV(obj)))->toString();
  return newSVpv( s.data(), s.length() );

}


SV* punt(SV* obj, SV* pkt) {

  ((Controller*) SvIV(SvRV(obj)))->deliver( ((Packet*) SvIV(SvRV(pkt))) );
  return newSViv(1);

}


SV* get_next_id(SV* obj) {

  std::string id = ((Controller*) SvIV(SvRV(obj)))->getNextID();
  return newSVpv( id.data(), id.length() );

}


SV* component_stop(SV* obj) {

  // stop it!
  ((Controller*) SvIV(SvRV(obj)))->disconnect();
  return newSViv(1);

}


Controller* c_ptr;
bool shutdown_flag;


static void death(int signal)
{
   if ( ! shutdown_flag )
   {
       shutdown_flag = true;
       cerr << " Component got a signal: " << signal << endl;
       c_ptr->disconnect();
   }
}




int runComponent(char* cid,
                 char* sec,
		 char* host,
		 int   prt,
		 char* mainpfunc,
		 char* initpfunc,
		 char* stoppfunc,
		 SV* myself)
{
    std::string       component_id = cid;
    std::string       secret       = sec;
    bool              outgoing     = true;
    std::string       nspace       = "jabber:component:" + component_id;

    std::string       jabberd_ip   = host;
    unsigned int      jabberd_port = prt;

    std::string       perl_func    = mainpfunc;
    std::string       init_pfunc   = initpfunc;
    std::string       stop_pfunc   = stoppfunc;
    void*             my_self    = myself;

    int retval;


    cerr << "[jax::RouterConnection] Starting component..."   << endl;
    cerr << "\tComponent ID : " << component_id <<endl;
    cerr << "\tJabberd IP   : " << jabberd_ip << endl;
    cerr << "\tJabberd Port : " << jabberd_port << endl << endl;


    Controller c;
    c.setPerlFunc(perl_func, init_pfunc, stop_pfunc, my_self);

    c_ptr = &c;


    jax::ComponentLoader loader(&c);
    signal(SIGPIPE, SIG_IGN);
    Application::registerShutdownSignal(SIGTERM);
    //Application::registerShutdownSignal(SIGINT);
    //Application::registerShutdownSignal(SIGHUP);

    shutdown_flag = false;
    signal(SIGINT, &death);
    signal(SIGHUP, &death);


    int myreturn = loader.start(jabberd_ip.c_str(), jabberd_port, outgoing, component_id.c_str(), secret.c_str(), nspace.c_str());

    cerr << "finished ....." << endl;
    // c.disconnect();
    //Application::stop(0, "Shutting Down ....");
    //Application::exit(0, "Exiting gracefully....");

    return myreturn;

}


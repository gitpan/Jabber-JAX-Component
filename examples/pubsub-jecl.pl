use strict;
use lib '../blib/lib';
use Jabber::JAX::Component;
use MyConfig qw(dbi jax);
my $config = MyConfig::get('dbi');
my $jaxconfig = MyConfig::get('jax');
use DBI qw(:sql_types);
use vars qw($DEBUG $DBH);

use Data::Dumper;

$DEBUG = 1;


=pod

= head1   pubsub-jecl.pl - Publish & Subscribe Jabber Component

This component is based on Jabber::JAX::Component - a perl module that binds
in the JECL libraries provided by DizzyD - http://www.jabberstudio.org

The component uses a MySQL database to store the subscription and roster information -
see the module MyConfig, and the setupdb.pl script for more details.


Create a config section in the server jabber.xml file like:
  <service id='pubsub.localhost'>
    <accept>
      <ip/>
      <port>5201</port>
      <secret>secret</secret>
    </accept>
    <pubsub.localhost xmlns='jabber:component:pubsub.localhost'>
   </pubsub.localhost>
  </service>


  This implements the protocol described in:
  http://www.jabber.org/jeps/jep-0024.html


=cut






# register of online presence
my $register = {};

# DB connection details for MySQL 
my $mcfg = {
	DB => 'mysql',
	DBName => $config->{'DBName'},
	DBHost => $config->{'DBHost'},
	DBUser => $config->{'DBUser'},
	DBPasswd => $config->{'DBPasswd'},
	};
# Connect to MySQL
my $mdbh = _check_connect( $mcfg );

my $c = 0;

my $conn = new Jabber::JAX::Component(
      component   => $jaxconfig->{'component'},
      secret      => $jaxconfig->{'secret'},
      host        => $jaxconfig->{'host'},
      port        => $jaxconfig->{'port'},
      handler     =>

      sub {
            my ( $rc, $p ) = @_;
	    debug( "Counter: ".$c++ );
            my $e = $p->getElement();
            my $type = $e->getName();

            debug("packet type is: $type");

            if ( $type eq "message" ){
	      process_message( $rc, $e, $p );
	    } elsif ( $type eq "iq" ){
	      process_iq( $rc, $e, $p );
	    } elsif ( $type eq "presence" ){
	      process_presence( $rc, $e, $p );
	    }
          },

      inithandler     =>
      sub {
            my ( $rc ) = @_;
	    debug( "Init Handler called " );
            my $query = _pubsub_db_sql("select * from roster where type = 'subscribed'");
            foreach my $row ( @{$query} ){
              my $pres = new Jabber::Judo::Element("presence");
              $pres->putAttrib("from", $jaxconfig->{'component'});
              $pres->putAttrib("to", $row->{'jid'});
              $pres->putAttrib("type", "available");
              $rc->deliver(new Jabber::JAX::Packet($pres));

              my $probe = new Jabber::Judo::Element("presence");
              $probe->putAttrib("from", $jaxconfig->{'component'});
              $probe->putAttrib("to", $row->{'jid'});
              $probe->putAttrib("type", "probe");
              $rc->deliver(new Jabber::JAX::Packet($probe));
	    }
          },

      stophandler     =>
      sub {
            my ( $rc ) = @_;
	    debug( "Stop Handler called " );
	    my %beenthere = ();
            foreach my $roster ( keys %{$register} ){
	      next unless $register->{$roster} eq 'online';
	      my ( $user, $host , $resource ) = $roster =~ m/^(\w+(?=\@))?\@?([\w \.\-]+)\/?([\w \-]+)?$/;
	      $roster = $user ? $user.'@'.$host : $host;
	      next if exists $beenthere{$roster};
	      $beenthere{$roster} = 1;
              my $pres = new Jabber::Judo::Element("presence");
              $pres->putAttrib("from", $jaxconfig->{'component'});
              $pres->putAttrib("to", $roster);
              $pres->putAttrib("type", "unavailable");
              $rc->deliver(new Jabber::JAX::Packet($pres));
	    }
          }
     );

$conn->start();


exit 0;


sub process_message {
  my ( $rc, $e, $p ) = @_;

  debug( "MESSAGE PACKET: ".$p->toString() );
  #my $to = $e->getAttrib('to');
  #$e->putAttrib('to', $e->getAttrib('from'));
  #$e->putAttrib('from', $to);
  #$rc->deliver( $p );
  unsupported($rc, $e, $p);

}

sub get_subscription {
  my ( $jid ) = @_;

  my $subscription = {};
  my $query = _pubsub_db_sql("select * from subscriptions where jid = '$jid'");

  foreach my $row ( @{$query} ){
    $subscription->{$row->{'publisher'}}->{$row->{'namespace'}} = 1;
  }
  return $subscription;

}

sub process_iq {
  my ( $rc, $e, $p ) = @_;

  debug( "IQ PACKET: ".$p->toString() );


  my $q = $e->findElement("query"); 
  unless ( $q ){
    debug("no query tag found - aborting ");
    unsupported($rc, $e, $p);
    return undef;
  }

  unless ( $q->getAttrib("xmlns") eq "jabber:iq:pubsub" ){
    debug("This IQ is not in the jabber:iq:pubsub namespace ");
    unsupported($rc, $e, $p);
    return undef;
  }

  my @subelems = $q->getChildren();

  if ( $e->getAttrib("type") eq "set" ){

    if ( $subelems[0]->getName() eq "publish" ){
      process_publish($rc, $e, $p);
    } elsif ( $subelems[0]->getName() =~ /subscribe/ ){
      process_subscription($rc, $e, $p);
    } else {
      unsupported($rc, $e, $p);
    } 
  } elsif( $e->getAttrib("type") eq "get" ) {
    # this is a get
    if ( $subelems[0]->getName() eq 'subscribe' ){
      process_subscription_get($rc, $e, $p);
    } else {
      unsupported($rc, $e, $p);
    } 
  } elsif( $e->getAttrib("type") eq "result" ) {
    debug( "IQ PACKET RESULT - WHY ONE OF THESE?? : ".$p->toString() );
  } else {
    unsupported($rc, $e, $p);
  } 
  

}


sub process_publish {
  my ($rc, $e, $p) = @_;

  my $from = $e->getAttrib("from");

  my $query = $e->findElement("query");
  my $good_packet = 1;
  foreach my $publish ( $query->getChildren() ){
    my $subtag = $publish->getName();
    if ($subtag != "publish") {
      debug("wrong sub packet type - must be a publish: ".$subtag);
      $good_packet = "";
      last;
    }
    # must have an ns tag
    unless ( $publish->getAttrib("ns") ){
      debug("publish tag must have ns tag with a value");
      $good_packet = "";
      last;
    }
    my $ns = $publish->getAttrib("ns");
    # loop at all the children of the publish and check that they are
    # <data>
    my $got_children = "";
    my @children = $publish->getChildren();
    unless ( scalar @children == 1 ){
      #  the child tag must have a namespace = to ns
      debug("publish data must have only 1 child tag: ");
      $good_packet = "";
      last;
    }
    unless ($children[0]->getAttrib("xmlns") eq $ns){
      debug("data must have xmlns tag with the same value as publish ns attrib: ".$ns);
      $good_packet = "";
      last;
    }
  } 

  unless ( $good_packet ){
    # Construct a response iq
    unsupported($rc, $e, $p);
    return;
  }

  # tell the publisher that the request was good
  my $pubres = new Jabber::Judo::Element("iq");
  $pubres->putAttrib("from", $e->getAttrib("to"));
  $pubres->putAttrib("to", $e->getAttrib("from"));
  $pubres->putAttrib("id", $e->getAttrib("id"));
  $pubres->putAttrib("type", "result");
  my $pq = $pubres->addElement("query");
  $pq->putAttrib("xmlns", "jabber:iq:pubsub");
  my $pqr = $pq->addElement("publish");
  $rc->deliver( new Jabber::JAX::Packet($pubres) );

  foreach my $publish ( $query->getChildren() ){

    my ( $pubdata ) = $publish->getChildren();
    my $ns = $publish->getAttrib("ns");
    my $query = _pubsub_db_sql("select jid from subscriptions where ( ( publisher = '$from' or publisher = 'all' ) and namespace = '$ns' ) or ( publisher = '$from' and namespace = 'all' )  group by jid");
    foreach my $row ( @{$query} ){
      
    if ( getSubscription($row-{'jid'}) eq "unsubscribed" ||
         getPresence($row-{'jid'}) eq "online" || $row->{'jid'} !~ /\@/  ) {
	 #  dont worry about components
        debug("Going to deliver to: ".$row->{'jid'});
        my $response = new Jabber::Judo::Element("iq");
        $response->putAttrib("from", $e->getAttrib("to"));
        $response->putAttrib("to", $row->{'jid'} );
        $response->putAttrib("id", $rc->getNextID());
        $response->putAttrib("type", "set");
        my $rquery_elem = $response->addElement("query");
        $rquery_elem->putAttrib("xmlns", "jabber:iq:pubsub");
        my $pub_elem = $rquery_elem->addElement("publish");
        $pub_elem->putAttrib("from", $e->getAttrib("from"));
        $pub_elem->putAttrib("ns", $ns);
        $rquery_elem->appendChild($pubdata);
        $rc->deliver( new Jabber::JAX::Packet($response) );
      }
    }
  }

}


sub process_subscription {
  my ($rc, $e, $p) = @_;

  my $from = $e->getAttrib("from");
  my $subscription = get_subscription($from);

  my $q = $e->findElement("query");
  my $good_packet = 1;
  foreach my $subs ( $q->getChildren() ){
    # all children are subscribes or unsubscribes
    my $subtag = $subs->getName();
    unless ($subtag eq "subscribe" || $subtag eq "unsubscribe"){
      debug("wrong sub packet type - must be a subscribe/unsubscribe: ".$subtag);
      $good_packet = "";
      last;
    }
    # all subscribe's must have a to attribute
    my $to = $subs->getAttrib("to") || "all";
    # loop at all the children of the subscribe and check that they are
    # <ns>
    my $got_children = "";
    foreach my $ns ( $subs->getChildren() ){
      # all children are ns
      unless ( $ns->getName() eq "ns" ){
        debug( "has non ns children tags" );
        $good_packet = "";
        last;
      }
      # the children must have a namespace inside
      unless ( $ns->getCDATA() ){
        debug( "ns must have some data");
        $good_packet = "";
        last;
      }
      $got_children = 1;
    }
    # finsh it now if it is allready bad
    last unless ( $good_packet );

    if ($subs->getName() eq "subscribe"){
      if (! $got_children && $to eq "all"){
        debug("a subscribe must have children if there is no to address");
	$good_packet = "";
	last;
      }
    }
  }
  unless ( $good_packet ){
    # Construct a response iq
    unsupported($rc, $e, $p);
    return;
  }

  debug( "Got a good packet ...");

  # we have a good packet so lets match and stash


  # if the subscriptio ndoesnt exist  then send presence
  #   subscription
  unless (_pubsub_db_sql("select * from roster where jid = '$from'") ){
    setSubscription($from, "unsubscribed");
    my $sub = new Jabber::Judo::Element("presence");
    $sub->putAttrib("from", $e->getAttrib("to"));
    $sub->putAttrib("to", $from);
    $sub->putAttrib("type", "subscribe");
    $rc->deliver(new Jabber::JAX::Packet($sub));
  }

  foreach my $p ( $q->getChildren() ){
    if ( $p->getName() eq "unsubscribe" ){
      if ( scalar ( $p->getChildren() ) == 0 ){
        if ( $p->getAttrib("to") ){
          # delete specific publisher
          delete $subscription->{$p->getAttrib("to")}
               if exists $subscription->{$p->getAttrib("to")};
        } else {
          #  delete them all
          $subscription = {};
        }
      } else {
        # unsubscribe has specific namespaces
        foreach my $ns ( $p->getChildren() ){
          if ( $p->getAttrib("to") ){
            # delete specific publisher
            delete $subscription->{$p->getAttrib("to")}->{$ns->getCDATA()}
                 if exists $subscription->{$p->getAttrib("to")}->{$ns->getCDATA()};
          } else {
            #  delete them all
            foreach my $sub ( keys %{$subscription} ){
              delete $subscription->{$sub}->{$ns->getCDATA()}
                   if exists $subscription->{$sub}->{$ns->getCDATA()};
            }
          }
        }
      }
    } else {
      # This is a subscription
      if ( scalar ( $p->getChildren() ) == 0 ){
        if ( $p->getAttrib("to") ){
          # subscribe to all namespaces of a specific publisher
          $subscription->{$p->getAttrib("to")}->{"all"} = 1;
        } else {
          #  subscribe to all publisher/namespaces - illegal
          die "SUBSCRIBE does not have namespaces or a publisher: ".$p->toString()."\n";
        }
      } else {
        # unsubscribe has specific namespaces
        foreach my $ns ( $p->getChildren() ){
          if ( $p->getAttrib("to") ){
            # subscribe to a namespace for a specific publisher
            $subscription->{$p->getAttrib("to")}->{$ns->getCDATA()} = 1;
          } else {
            #  remove any publisher specific subscriptions and subscribe to this namespace for all publishers
            foreach my $sub ( keys %{$subscription} ){
              delete $subscription->{$sub}->{$ns->getCDATA()}
                   if exists $subscription->{$sub}->{$ns->getCDATA()};
            }
            $subscription->{"all"}->{$ns->getCDATA()} = 1;
          }
        }
      }
    }
  } 

  # update the subscription DB
  _pubsub_db_sql("delete from subscriptions where jid = '$from'");
  foreach my $pub ( sort keys %{$subscription} ){
    foreach my $ns ( sort keys %{$subscription->{$pub}} ){
      _pubsub_db_sql("insert into subscriptions values('$from', '$pub', '$ns')");
    }
  }

  my $to = $e->getAttrib('to');
  $e->putAttrib('to', $e->getAttrib('from'));
  $e->putAttrib('from', $to);
  $e->putAttrib('type', 'result');
  $rc->deliver( $p );

}


sub process_subscription_get {
  my ($rc, $e, $p, $subscription) = @_;
  # This is an IQ get - so send back the subscription data

  my $from = $e->getAttrib("from");
  my $subscription = get_subscription($from);

  my $to = $e->getAttrib('to');
  $e->putAttrib('to', $from);
  $e->putAttrib('from', $to);
  $e->putAttrib('type', 'result');

  my $q = $e->findElement("query");
  $q->delElement("subscribe");

  foreach my $pub ( sort keys %{$subscription} ){
    my $publisher = $q->addElement("subscribe");
    $publisher->putAttrib("to", $pub) unless $pub eq "all";
    foreach my $ns ( sort keys %{$subscription->{$pub}} ){
      next if $ns eq "all";
      my $nspace = $publisher->addElement("ns");
  	$nspace->addCDATA($ns);
    }
  }

  $rc->deliver( $p );

}


sub unsupported {
  my ($rc, $e, $p) = @_;
  debug( "THIS PACKET IS UNSUPPORTED: ".$p->toString() );

  return if $e->getAttrib("type") eq "error";
  my $resp = new Jabber::Judo::Element($e->getName());
  $resp->putAttrib('to', $e->getAttrib("from"));
  $resp->putAttrib('from', $e->getAttrib('to'));
  $resp->putAttrib('id', $e->getAttrib('id')) if $e->getAttrib('id');
  $resp->putAttrib('type', 'error');
  my $err = $resp->addElement("error");
  $err->putAttrib("code", "400");
  $err->addCDATA("Malformed jabber:iq:pubsub query");
  $rc->deliver( new Jabber::JAX::Packet($resp ) );

}



sub process_presence {
  my ( $rc, $e, $p ) = @_;

  debug( "PRESENCE PACKET: ".$p->toString() );
  #$e->putAttrib('to', $e->getAttrib('from'));
  #$e->putAttrib('from', $to);
  #$rc->deliver( $p );


  my $to = $e->getAttrib("to");
  if ($e->getAttrib("type") eq "subscribe"){
    # allow their subscribe request..
    my $pres = new Jabber::Judo::Element("presence");
    $pres->putAttrib("from", $to);
    $pres->putAttrib("to", $e->getAttrib("from"));
    $pres->putAttrib("type", "subscribed");
    $rc->deliver(new Jabber::JAX::Packet($pres));

    # request their subscription ...
    my $sub = new Jabber::Judo::Element("presence");
    $sub->putAttrib("from", $to);
    $sub->putAttrib("to", $e->getAttrib("from"));
    $sub->putAttrib("type", "subscribe");
    $rc->deliver(new Jabber::JAX::Packet($sub));

    # push our presence
    my $here = new Jabber::Judo::Element("presence");
    $here->putAttrib("from", $to);
    $here->putAttrib("to", $e->getAttrib("from"));
    $rc->deliver(new Jabber::JAX::Packet($here));

    # update our roster
    setSubscription($e->getAttrib("from"), "subscribed");
  }
  if ($e->getAttrib("type") eq "unsubscribe"){
    # allow their unsubscribe request..
    my $pres = new Jabber::Judo::Element("presence");
    $pres->putAttrib("from", $to);
    $pres->putAttrib("to", $e->getAttrib("from"));
    $pres->putAttrib("type", "unsubscribed");
    $rc->deliver(new Jabber::JAX::Packet($pres));

    # ask them to remove us
    my $remove = new Jabber::Judo::Element("presence");
    $remove->putAttrib("from", $to);
    $remove->putAttrib("to", $e->getAttrib("from"));
    $remove->putAttrib("type", "unsubscribe");
    $rc->deliver(new Jabber::JAX::Packet($remove));

    # update our roster
    setSubscription($e->getAttrib("from"), "unsubscribed");
  }

  if ($e->getAttrib("type") eq "unavailable"){
    setPresence($e->getAttrib("from"), "offline");
  }

  if ($e->getAttrib("type") eq "probe"){
    setPresence($e->getAttrib("from"), "online");
    my $pres = new Jabber::Judo::Element("presence");
    $pres->putAttrib("from", $to);
    $pres->putAttrib("to", $e->getAttrib("from"));
    $rc->deliver(new Jabber::JAX::Packet($pres));
  }

  if ($e->getAttrib("type") eq "available" || ! $e->getAttrib("type") ){
    setPresence($e->getAttrib("from"), "online");
  }

}


sub getSubscription {
  my ( $from ) = @_;

  my ( $user, $host , $resource ) = $from =~ m/^(\w+(?=\@))?\@?([\w \.\-]+)\/?([\w \-]+)?$/;
  $from = $user ? $user.'@'.$host : $host;
  my $query = _pubsub_db_sql("select * from roster where jid = '$from'");
  my $status = "unsubscribed";
  foreach my $row ( @{$query} ){
    $status = $row->{'type'};
  }
  return $status;

}


sub setSubscription {
  my ( $from, $status ) = @_;

  my ( $user, $host , $resource ) = $from =~ m/^(\w+(?=\@))?\@?([\w \.\-]+)\/?([\w \-]+)?$/;
  $from = $user ? $user.'@'.$host : $host;
  _pubsub_db_sql("delete from roster where jid = '$from'");
  _pubsub_db_sql("insert into roster values('$from', '$status')");

}


sub setPresence {
  my ( $from, $status ) = @_;

  $register->{$from} = $status;

}


sub getPresence {
  my ( $from ) = @_;

  return exists $register->{$from} ? $register->{$from} : "offline";

}


sub _pubsub_db_sql {
  my ( $query ) = @_;
  my $dbh = _check_connect( $mcfg );
  # debug("DB: READING DB QUERY: $query");
  my $sthr = $dbh->prepare( $query );
  eval { $sthr->execute() };
  if ( $@ ){
    debug("DB: CANT READ  DB QUERY: $query".
          "Can't read: $DBI::errstr $@\n");
    return undef;
  };

  if ( $query =~ /^select/ ){
    my @rows;
    while ( my $row = $sthr->fetchrow_hashref('NAME_lc') ) { push(@rows, $row) };
    if ( scalar @rows == 0 ){
      # debug("PUBSUB READ failed: $query ");
      return undef;
    } else {
      return scalar @rows > 0 ? [ @rows ] : undef ;
    }
  } else {
    return undef;
  }

}


sub _check_connect{

  my ($config) = @_;
  my $dbh = "";
  if ( ! $DBH ){
    debug("DB: Totally NEW Connection DBHOST: ".$config->{'DBHost'}.
        " DB: ".$config->{'DBName'}." USER: ".$config->{'DBUser'}.
        " PWD: ".$config->{'DBPasswd'});
    $dbh  = _connect_to_db( 
		     $config->{'DB'},
		     $config->{'DBName'},
		     $config->{'DBHost'},
		     $config->{'DBUser'},
		     $config->{'DBPasswd'}
		    );
  } else {
    eval { $DBH->ping };
    if ( $@ ){
      debug("DB: DSCONNECTED - NEW Connection ". "DBHOST: ".$config->{'DBHost'},
            "DB: ".$config->{'DBName'}."USER: ".$config->{'DBUser'}.
            "PWD: ".$config->{'DBPasswd'});
      $dbh  = _connect_to_db( 
		     $config->{'DB'},
		     $config->{'DBName'},
		     $config->{'DBHost'},
		     $config->{'DBUser'},
		     $config->{'DBPasswd'}
		    );
    } else { 
     # debug("DB: CACHED Connection ". "DBHOST: ".$config->{'DBHost'});
      $dbh = $DBH;
    }
 }
 return $dbh;

}


sub _connect_to_db{

  my ($db, $dbname, $dbhost, $dbuser, $dbpasswd) = @_;
  my $conn = "DBI:$db:$dbname;host=$dbhost";
  my $dbh = "";
  eval {
     $dbh = DBI->connect($conn,
			 "$dbuser","$dbpasswd",
			 {RaiseError => 1} );
 };
 if ( $@ ){
     debug("DB: CANT CONNECT TO DB: $db DBHOST: ".$dbhost.
	   " DB: ".$dbname."USER: ".$dbuser.
	   " PWD: ".$dbpasswd."Can't connect: $DBI::errstr ".$@);
     return undef;
 };

 $DBH = $dbh;
 return $dbh;

}


sub debug{

  return unless $DEBUG;
  print  STDERR scalar localtime().": ", @_, "\n";

}


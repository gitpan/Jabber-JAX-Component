#!/web/gccperl561/bin/perl
#  Create a data base 
use DBI;
$db = $config->{"DBName"};
use MyConfig qw(dbi);

my $config = MyConfig::get('dbi');

# Connect to database 
$dbh = DBI->connect("DBI:mysql:$db;host=".$config->{'DBHost'},$config->{"DBUser"},$config->{"DBPasswd"}) 
        || die "Can't connect: $DBI::errstr\n";

# List the data bases
&show_databases();

#$dbh->do("drop database $db") ||
#      die " Cant drop data base time: $DBI::errstr\n";

#print "\n $db dropped .... \n\n";

# Create the data base
#$dbh->do("create database $db") || die " Cant create data base time: $DBI::errstr\n";

&show_databases();

#print "\n $db Created .... \n\n";

&show_tables();


$dbh->do("drop table subscriptions") ||
       warn " Cant drop table subscriptions: $DBI::errstr\n";
#$dbh->do("create table subscriptions (jid char(100) not null, publisher char(100) not null, namespace char(100) not null, primary key (jid, publisher, namespace))") ||
$dbh->do("create table subscriptions (jid char(100) not null, publisher char(100) not null, namespace char(100) not null)") || die " Cant create table subscriptions: $DBI::errstr\n";

$dbh->do(" create index jid on subscriptions ( jid ) ") || die " Cant create table subscriptions: $DBI::errstr\n";
$dbh->do(" create index publisher on subscriptions ( publisher, namespace ) ") || die " Cant create table subscriptions: $DBI::errstr\n";

$dbh->do("create table roster (jid char(100) not null, type char(20) not null, primary key (jid))") || die " Cant create table roster: $DBI::errstr\n";

&show_tables();


# List Databases
sub show_databases{
  $sth = $dbh->prepare("show databases");
  $sth->execute() || die "Can't show databases: $DBI::errstr\n";
  print "\n\n  Databases Available \n";
  print "-----------------------\n";
  while ( $ref = $sth->fetchrow() ){
    print "   $ref \n";
    $hd{$ref}=$ref;
  };
}


# List tables
sub show_tables{
  $stht = $dbh->prepare("show tables");
  $stht->execute() || die "Can't show tables: $DBI::errstr\n";
  print "\n\n  Databases Tables NOW Available \n";
  print "--------------------------------------\n";
  while ( $ref = $stht->fetchrow() ){
    print "   $ref \n";
    $ht{$ref}=$ref;
  };
  print "\n-----------------------------------\n";
  print "\n\n";
}



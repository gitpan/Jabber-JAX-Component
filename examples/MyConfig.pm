package MyConfig;

# $Id: MyConfig.pm,v 1.2 2002/04/12 14:43:33 piers Exp $

=pod

=head1 MyConfig - a Config handler

This module is used as a generic config handler so things like
hostnames, userids and passwords can be easily abstracted out to a file

the key is the first word of each line of a file, the config value is the remainder
of the line after the first block of whitespace after the key ( see examples below )

If you want to change the source directory for config files - then change the 
CONFIG_DIR constant below


    example dbi.config
    ==================
    DBName   pubsub
    DBHost   myhost
    DBUser   myuser
    DBPasswd secret


    example jax.config
    ==================
    component   pubsub.localhost
    secret      secret
    host        localhost.localdomain
    port        5201


=cut


use strict;
use constant CONFIG_DIR => './';
#use Data::Dumper;

my %config;


sub import {
  
  shift;  # remove the package name

  # Add the config names to look up
  my %files = ();
  map { $files{$_} = 1 } @_;

  local $/ = "\n";
  opendir(DIR, CONFIG_DIR) or die "Cannot open config dir: $!\n";

  # Take all the *.config files in the CONFIG_DIR
  foreach my $config_file (grep { /^.+?\.config$/ } readdir(DIR)) {

    # Config type, e.g. 'ldap'
    my ($config_type) = $config_file =~ m|^(.+?)\.config$|; 
     
    # check that the file is one we want 
    next if ! exists $files{$config_type} && keys %files;
    
    # Open the file
    open(CONFIG, CONFIG_DIR.$config_file) or die "Cannot read $config_file: $!\n";

    # Read contents, parse into name/value pairs, and store
    while (<CONFIG>) {
      next if m/(^#|^\s*$)/; # ignore blank lines and comments
      chomp;
      my ($name, $value) = split(/\s+/, $_, 2);
      if ( $value =~ /\\$/ ){
        #  accumulate continued lines
        while (<CONFIG>) {
          next if m/(^#|^\s*$)/; # ignore blank lines and comments
          chomp;
	  chop $value;
          $value .= $_;
	  #print STDERR "VALUE: $value \n";
	  last unless $_ =~ /\\$/;
	}
      }
      # next 2 lines turn multi value items into arrayref, defined with [..]
      #print STDERR "VALUE: $value \n";
      $value = [ split("\t",$1) ] if $value =~ /^\[(.*?)\]/;
      eval "\$value = $value " if $value =~ /^\{(.*?)\}/;
      $config{$config_type}->{$name} = $value;
    }

    # Close the file
    close(CONFIG);

}

closedir DIR;

}



sub get {
  my $section = shift;
  #print STDERR Dumper(\%config);
  return $section ? $config{$section} : %config;

}

1;


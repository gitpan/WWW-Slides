package ClientTest;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw( start_child_server echo get_stuff );

sub start_child_server {
   my ($port, $child_sub) = @_;

   require IO::Socket;
   my $server = IO::Socket::INET->new(
      LocalPort => $port,
      ReuseAddr => 1,
      Listen    => 1,
     )
     or die "could not listen on port $port: $!";

   my $pid = fork();
   die "fork(): $!" unless defined $pid;
   return if $pid;

   $SIG{ALRM} = sub { exit 1 };
   alarm 5;    # Complete by this time
   my $sock = $server->accept();
   alarm 0;

   $child_sub->($server, $sock) if $child_sub;
   exit 0;
} ## end sub start_child_server

sub echo {
   my ($server, $sock) = @_;
   while ($sock->sysread(my $buffer, 1024)) {
      $sock->print($buffer);
   }
} ## end sub echo

sub get_stuff {
   my ($fh) = @_;
   $fh->sysread(my $buffer, 1024);
   return $buffer;
}

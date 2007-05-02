use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;
use Test::MockObject;
use IO::Socket;

my $module = 'WWW::Slides::Attendee';
require_ok($module);

throws_ok { $module->new() } qr/mandatory/msx,
  'balks for incomplete constructor';


my ($r, $w);
pipe $r, $w;
$w->autoflush();

# Be sure not to make it stuck forever
$SIG{ALRM} = sub { die 'sorry, timed out!' };
alarm(5); # A reasonable timeout

my $pid = fork();
die "could not fork" unless defined $pid;

my $port = 60505;

if (! $pid) { # child
   $w->close();
   $r->sysread(my $go_on, 1);
   my $sock = IO::Socket::INET->new(
      PeerAddr => 'localhost',
      PeerPort => $port,
      Proto    => 'tcp',
   );

   $sock->print("ciao"); # 4 chars

   $r->sysread($go_on, 1);
   $sock->print("ariciao"); # 7 chars
   
   $r->sysread($go_on, 1);
   $sock->close();
   
   exit 0;
}


my $listener = IO::Socket::INET->new(
   LocalPort => $port,
   Proto     => 'tcp',
   Listen    => 1,
);
$r->close();
$w->print('x');
my $fh = $listener->accept();

my %slide_show = (
   preamble => "this is the preamble\n",
   slides   =>
     ["*** slide 1 ***\n", "*** slide 2 ***\n", "*** slide 3 ***\n",],
);
my $slide_show = Test::MockObject->new();
$slide_show->set_true('add_headers');
$slide_show->set_always('get_preamble', $slide_show{preamble});
$slide_show->mock(
   'get_slide',
   sub {
      my ($self, $n) = @_;
      return $slide_show{slides}[$n];
   }
);
$slide_show->mock(
   'get_show_div',
   sub {
      my ($self, $n) = @_;
      return "please show ", $n + 1, "\n";
   }
);

my $attendee;
lives_ok {
   $attendee =
     $module->new(
      {handle => $fh, slide_show => $slide_show, current_slide => 0});
  }
  'constructor ok with all mandatory parameters';

is($attendee->handle_input(), 4, 'correctly dropped first 4 chars');

$w->print('x');
is($attendee->handle_input(), 7, 'correctly dropped next 7 chars');

$w->print('x');
ok(! $attendee->handle_input(), 'client exited');

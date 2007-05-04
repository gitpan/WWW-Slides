# vim: filetype=perl :
use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use File::Basename qw( dirname );
use IO::Handle;

use lib dirname(__FILE__);
use ClientTest qw( get_stuff );

my $module = 'WWW::Slides::Client::Base';
require_ok($module);

pipe my ($in, $myout);
ok($in && $myout, 'pipe ok');
$myout->autoflush();
pipe my ($myin, $out);
ok($myin && $out, 'pipe ok');
$out->autoflush();

my $object;
lives_ok { $object = $module->new(in_handle => $in, out_handle => $out) }
  'builds correctly';
can_ok($object, qw( get_current get_attendees ));

# Pre-send answer :)
$myout->print("200 OK current=9;total=42\n");
my ($current, $total) = $object->get_current();
like(
   get_stuff($myin),
   qr/\Acommand=get_current \s*\n\z/mxs,
   'get_stuff command sent out'
);
is($current, 9,  'get_current: current value parsed correctly');
is($total,   42, 'get_current: total parsed correctly');

# Pre-send answer
$myout->print("200 OK\nid=1;value=pippo\nid=2;value=pluto\n");
my @attendees = $object->get_attendees();
like(
   get_stuff($myin),
   qr/\Acommand=get_attendees \s*\n\z/mxs,
   'get_attendees command sent out'
);
is_deeply(
   \@attendees,
   [{id => 1, value => 'pippo'}, {id => 2, value => 'pluto'}],
   'get_attendees: parsed correctly'
);

# Pre-send answer
$myout->print("200 OK\nid=1;value=pippo\nid=2;value=pluto\n");
my $attendees = $object->get_attendees();
is(ref $attendees, 'ARRAY', 'invocation in scalar context');
like(
   get_stuff($myin),
   qr/\Acommand=get_attendees \s*\n\z/mxs,
   'get_attendees command sent out'
);
is_deeply(
   $attendees,
   [{id => 1, value => 'pippo'}, {id => 2, value => 'pluto'}],
   'get_attendees: parsed correctly'
);

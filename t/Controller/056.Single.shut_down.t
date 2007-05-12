use strict;
use warnings;

use Test::More tests => 13;
use Test::Exception;
use IO::Handle;

use File::Basename qw( dirname );
use lib dirname(__FILE__) . '/..';
use MemoryFilehandle
  qw( in_memory_handle out_memory_handle has_in_memory_handles);

SKIP:
{
   skip('need in-memory filehandles for these tests', 13)
     unless has_in_memory_handles();

   my ($in_string, $out_string);
   my $out = out_memory_handle($out_string);
   my $in  = in_memory_handle($in_string);
   my $sel = TestSelector->new();

   my $module = 'WWW::Slides::Controller::Single';
   require_ok($module);

   my $object;
   lives_ok {
      $object = $module->new(
         in_handle  => $in,
         out_handle => $out,
      );
     } ## end lives_ok
     'correctly builds with mandatory and optional parameters';

   ok($object->is_alive(), 'object is alive');

   lives_ok { $object->set_selector($sel) } 'set_selector';
   is($sel->{add}, 1, 'selector correctly invoked');
   is($sel->{remove}, 0, 'no removal yet in selector');

   my $msg = 'ciao';
   lives_ok { $object->output($msg) } 'output lives';
   is($out_string, $msg,
      'output method correctly outputting to out_handle');
   my $out_mark = length $out_string;

   lives_ok { $object->shut_down(); } 'shut_down lives';
   ok(!($object->is_alive()), 'object is dead');
   is($sel->{remove}, 1, 'selector notified for removal');

   throws_ok { $object->output($msg) } qr/no output possible/, 
      'output dies after shut_down';
   is(substr($out_string, $out_mark), '', 'no actual output after shut_down');
} ## end SKIP:

# I need the following because Test::MockObject does not allow
# mocking of 'remove' methods :/
package TestSelector;
sub new { return bless {add => 0, remove => 0}, shift }
sub add    { return shift->{add}++ }
sub remove { return shift->{remove}++ }
1;

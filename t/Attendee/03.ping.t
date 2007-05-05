use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::MockObject;

use File::Basename qw( dirname );
use lib dirname(__FILE__) . '/..';
use MemoryFilehandle qw( in_memory_handle );

my $module = 'WWW::Slides::Attendee';
require_ok($module);

throws_ok { $module->new() } qr/mandatory/msx,
  'balks for incomplete constructor';

SKIP:
{
   my $target;
   my $fh = in_memory_handle($target);
   skip('Need in-memory filehandles or IO::String for these tests', 3)
     unless $fh;

   throws_ok { $module->new(handle => $fh) } qr/mandatory/,
     'balks for incomplete constructor';

   my %slide_show = (
      preamble => "this is the preamble\n",
      slides   =>
        ["*** slide 1 ***\n", "*** slide 2 ***\n", "*** slide 3 ***\n",],
      ping => 'ping!',
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
   $slide_show->set_always(get_ping => $slide_show{ping});

   my $attendee;
   lives_ok {
      $attendee =
        $module->new(
         {handle => $fh, slide_show => $slide_show, current_slide => 0});
     }
     'constructor ok with all mandatory parameters';

   {
      my $pre = length $target;
      $attendee->ping();
      is(substr($target, $pre), $slide_show{ping}, 'ping correctly sent');
   }
} ## end SKIP:

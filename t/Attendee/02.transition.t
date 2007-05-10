use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Test::MockObject;

use File::Basename qw( dirname );
use lib dirname(__FILE__) . '/..';
use MemoryFilehandle qw( out_memory_handle );

my $module = 'WWW::Slides::Attendee';
require_ok($module);

throws_ok { $module->new() } qr/mandatory/msx,
  'balks for incomplete constructor';

SKIP:
{
   my $target;
   my $fh = out_memory_handle($target);
   skip('Need in-memory filehandles or IO::String for these tests', 7)
     unless $fh;

   throws_ok { $module->new(handle => $fh) } qr/mandatory/,
     'balks for incomplete constructor';

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
      'get_hide_div',
      sub {
         my ($self, $n) = @_;
         return "please hide ", $n + 1, "\n";
      }
   );
   $slide_show->mock(
      'get_show_div',
      sub {
         my ($self, $n) = @_;
         return "please show ", $n + 1, "\n";
      }
   );
   $slide_show->set_true('validate_slide_id');
   $slide_show->mock(id_first    => sub { return 0 });
   $slide_show->mock(id_last     => sub { return 2 });
   $slide_show->mock(id_next     => sub { return $_[1] + 1 });
   $slide_show->mock(id_previous => sub { return $_[1] - 1 });

   my $attendee;
   lives_ok {
      $attendee =
        $module->new(
         {handle => $fh, slide_show => $slide_show, current_slide => 0});
     }
     'constructor ok with all mandatory parameters';

   {
      my $pre = length $target;
      $attendee->show(2);
      is(
         substr($target, $pre),
         "please hide 1\n$slide_show{slides}[2]please show 3\n",
         'correctly sent absolute slide'
      );
   }
   {
      my $pre = length $target;
      $attendee->show_first();
      is(
         substr($target, $pre),
         "please hide 3\nplease show 1\n",
         'correctly returned to first slide'
      );
   }
   {
      my $pre = length $target;
      $attendee->show_last();
      is(
         substr($target, $pre),
         "please hide 1\nplease show 3\n",
         'correctly jumped to last slide'
      );
   }
   {
      my $pre = length $target;
      $attendee->show_previous();
      is(
         substr($target, $pre),
         "please hide 3\n$slide_show{slides}[1]please show 2\n",
         'correctly called previous slide'
      );
   }
   {
      my $pre = length $target;
      $attendee->show_next();
      is(
         substr($target, $pre),
         "please hide 2\nplease show 3\n",
         'correctly called next slide'
      );
   }
} ## end SKIP:

__END__

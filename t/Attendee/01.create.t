use strict;
use warnings;
use English qw( -no_match_vars );
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

   my ($header, $body) = split /\r\n\r\n/, $target;
   like(
      $header,
      qr{\AHTTP/1.1 \s+ 200 \s+ OK \r\n}mxs,
      'HTTP header incipit and status'
   );
   like($header, qr/^Date:/mxs,         'header has a date field');
   like($header, qr/^Content-Type:/mxs, 'header has a content-type field');
   unlike($header, qr/[^\r]\n/mxs, 'line terminator is \r\n');
   is(
      $body,
      $slide_show{preamble} . $slide_show{slides}[0] . "please show 1\n",
      'answer body is correct'
   );
} ## end SKIP:

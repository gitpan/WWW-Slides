use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;

use File::Basename qw( dirname );
use lib dirname(__FILE__) . '/..';
use MemoryFilehandle qw( out_memory_handle );

SKIP:
{
   my $target;
   my $fh = out_memory_handle($target);
   skip('need in-memory filehandles for these tests', 3)
     unless $fh;

   my $module = 'WWW::Slides::Controller::Single';
   require_ok($module);

   my $object;
   lives_ok {
      $object = $module->new(in_handle => 1, out_handle => $fh);
     }
     'correctly builds with mandatory and optional parameters';

   my $msg = 'ciao';
   $object->output($msg);
   is($target, $msg, 'output method correctly outputting to out_handle');
} ## end SKIP:

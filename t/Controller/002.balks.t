# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 10; # last test to print
use Test::Exception;

my $module = 'WWW::Slides::Controller';
require_ok($module);

my $object;
lives_ok { $object = $module->new() }
  'correctly builds without parameters';

for my $method_name (qw( is_alive owns get_input_chunk output )) {
   my $method = $object->can($method_name);
   ok($method, "got method $method_name");
   throws_ok { $object->$method() } qr/overridden/msxi,
      "balks at $method_name()";
}

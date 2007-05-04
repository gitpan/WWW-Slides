# vim: filetype=perl :
use strict;
use warnings;
use Test::More tests => 34;
use Test::Exception;
use File::Basename qw( dirname );
use IO::Handle;

my $module = 'WWW::Slides::Client::Base';
require_ok($module);

pipe my ($in, $out);
ok($in && $out, 'pipe ok');
$out->autoflush();

my $object;
lives_ok { $object = $module->new(in_handle => $in, out_handle => $out) }
  'builds correctly';
can_ok(
   $object, qw(
     raw_send receive send_command
     first last previous next show
     attach detach clamp loose
     book quit
     get_current get_attendees
     shut_down is_alive
     )
);

my $message = 'ciao';
ok($object->raw_send($message), 'raw_send');
is($object->receive(), $message, 'receive');
is($object->send_command($message), "$message\n", 'send_command');

for my $command (qw( first last previous next attach detach )) {
   my $method = $object->can($command);

   like(
      $object->$method(),
      qr/\A command=$command \s+ target=\s*\n\z/mxs,
      "$command (no targets)"
   );
   like(
      $object->$method('ciao'),
      qr/\A command=$command \s+ target=ciao \s*\n\z/mxs,
      "$command (one target)"
   );
   like(
      $object->$method(qw( ciao a tutti )),
      qr/\A command=$command \s+ target=ciao,a,tutti \s*\n\z/mxs,
      "$command (three targets)"
   );
} ## end for my $command (qw( first last previous next attach detach ))

like(
   $object->show(4),
   qr/\Acommand=show \s+ slide=4 \s+ target= \s*\n\z/mxs,
   'show (no targets)'
);
like(
   $object->show(4, 'ciao'),
   qr/\Acommand=show \s+ slide=4 \s+ target=ciao \s*\n\z/mxs,
   'show (one target)'
);
like(
   $object->show(4, qw( ciao a tutti )),
   qr/\Acommand=show \s+ slide=4 \s+ target=ciao,a,tutti \s*\n\z/mxs,
   'show (three targets)'
);

like($object->clamp(), qr/\A command=clamp \s*\n\z/mxs, 'clamp');
like($object->loose(), qr/\A command=loose \s*\n\z/mxs, 'loose');

like($object->book('ciao'), qr/\A command=book \s+ code=ciao \s*\n\z/mxs,
   'book');
like($object->quit(), qr/\A command=quit \s*\n\z/mxs, 'quit');

ok($object->is_alive(), 'object is alive');
$object->shut_down();
ok(! $object->is_alive(), 'object is shut');

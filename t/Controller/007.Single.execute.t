use strict;
use warnings;

use Test::More tests => 90;
use Test::Exception;
use IO::Handle;

# No more than 10 seconds for the whole test
$SIG{ALRM} = sub {
   die "something hanged, bailing out this test file";
};
alarm(10);

my ($in, $to_controller, $out, $from_controller);
my $current   = 3;
my $total     = 42;
my @attendees = ({ciao => 'a'}, {tutti => 'quanti'},);
SKIP:
{
   pipe $in,              $to_controller;
   pipe $from_controller, $out;
   skip('need in-memory filehandles for these tests', 13)
     unless $in && $out && $to_controller && $from_controller;
   $out->autoflush();
   $to_controller->autoflush();

   my $talk = TestTalk->new();

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

   # On with the real stuff
   # Straight commands, accepting some targets
   for my $command (qw( first last next previous attach detach )) {
      for my $targets ([], [qw( ciao a tutti )]) {
         my $tstr = join(',', @$targets) || '';
         $to_controller->print("command=$command target=$tstr\n");
         lives_ok { $object->execute_commands($in, $talk) }
           "$command remote command lives";
         is(last_out(), "200 OK\n", "output for $command (@$targets)");
         my ($method, $args) = $talk->next_call();
         like($method, qr/\A(?:show_)?$command\z/mxs,
            'correct command invoked on talk');
         shift @$args;    # Remove talk object itself
         is_deeply($args, $targets,
            'talk method invoked with correct args');
      } ## end for my $targets ([], [qw( ciao a tutti )...
   } ## end for my $command (qw( first last next previous attach detach ))

   # show command requires slide number
   for my $targets ([], [qw( ciao a tutti )]) {
      my $slide = int(rand 13);
      my $tstr = join(',', @$targets) || '';
      $to_controller->print("command=show slide=$slide target=$tstr\n");
      lives_ok { $object->execute_commands($in, $talk) }
        "show remote command lives";
      is(last_out(), "200 OK\n", "output for show (@$targets)");
      my ($method, $args) = $talk->next_call();
      is($method, 'show', 'correct command invoked on talk');
      shift @$args;    # Remove talk object itself
      is_deeply(
         $args,
         [$slide, @$targets],
         'talk method invoked with correct args'
      );
   } ## end for my $targets ([], [qw( ciao a tutti )...

   # clamp, loose and quit, no option needed
   for my $command (qw( clamp loose quit )) {
      $to_controller->print("command=$command\n");
      lives_ok { $object->execute_commands($in, $talk) }
        "$command remote command lives";
      is(last_out(), "200 OK\n", "output for $command");
      my ($method, $args) = $talk->next_call();
      is($method, $command, 'correct command invoked on talk');
      is(scalar @$args, 1, "no arg passed to talk method $command");
   } ## end for my $command (qw( clamp loose quit ))

   # book
   {
      my $code = 'WWW::Slides::Rocks';
      $to_controller->print("command=book code=$code\n");
      lives_ok { $object->execute_commands($in, $talk) }
        'book remote command lives';
      is(last_out(), "200 OK\n", 'output for book');
      my ($method, $args) = $talk->next_call();
      is($method,       'book', 'correct command invoked on talk');
      is(scalar @$args, 2,      'one arg passed to talk method book');
      is($args->[1],    $code,  'code received and passed correctly');
   }

   # get_current
   {
      $to_controller->print("command=get_current\n");
      lives_ok { $object->execute_commands($in, $talk) }
        'get_current remote command lives';
      is(
         last_out(),
         "200 OK current=$current;total=$total\n",
         'output for get_current'
      );
      my ($method, $args) = $talk->next_call();
      is($method, 'get_current', 'correct command invoked on talk');
      is(scalar @$args, 1, 'no arg passed to talk method get_current');
      ($method, $args) = $talk->next_call();
      is($method, 'get_total', 'correct command invoked on talk');
      is(scalar @$args, 1, 'no arg passed to talk method get_total');
   }

   # get_attendees
   {
      $to_controller->print("command=get_attendees\n");
      lives_ok { $object->execute_commands($in, $talk) }
        'get_attendees remote command lives';

      my @output = split /\n/, last_out();
      is(scalar @output, 3, 'output has correct number of lines');
      is($output[0], '200 OK', 'first line is correct');

      shift @output;
      my @received = map {
         {
            map { split /=/ } split /;/
         }
      } @output;
      is_deeply(\@received, \@attendees, 'attendee data correct');

      my ($method, $args) = $talk->next_call();
      is($method, 'get_attendees_details',
         'correct command invoked on talk');
      is(scalar @$args, 1, 'no arg passed to talk method get_current');
   }

   # inexistent command leads to 500 error
   $to_controller->print("command=inexistent\n");
   lives_ok { $object->execute_commands($in, $talk) }
      'inexistent command does not bomb it all';
   like(last_out(), qr/\A500\s+/msx, 'error for inexistent command');
} ## end SKIP:

# Test ok, rest alarm
alarm(0);

sub last_out {
   $from_controller->sysread(my $buffer, 1024);
   return $buffer;
}

package TestTalk;
use Test::MockObject;

sub new {
   my $self = Test::MockObject->new();
   $self->set_true(
      qw(
        show_first show_last show_next show_previous show
        attach detach clamp loose
        book quit
        )
   );
   $self->set_always(get_current => $current);
   $self->set_always(get_total   => $total);
   $self->set_list('get_attendees_details', @attendees);
} ## end sub new
1;

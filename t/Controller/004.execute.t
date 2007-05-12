use strict;
use warnings;

#use Test::More tests => 88;
use Test::More 'no_plan';
use Test::Exception;
use IO::Handle;

my $current   = 3;
my $total     = 42;
my @attendees = ({ciao => 'a'}, {tutti => 'quanti'},);

my $talk = TestTalk->new();

my $module = 'TestController';
my ($object, $input, $output);
lives_ok {
   $object = $module->new(input => \$input, output => \$output);
  }
  "$module derived class builds";

# On with the real stuff
# Straight commands, accepting some targets
for my $command (qw( first last next previous attach detach )) {
   for my $targets ([], [qw( ciao a tutti )]) {
      my $tstr = join(',', @$targets) || '';
      $input = "command=$command target=$tstr\n";
      lives_ok { $object->execute_commands(undef, $talk) }
        "$command remote command lives";
      is($output, "200 OK\n", "output for $command (@$targets)");

      my ($method, $args) = $talk->next_call();
      like($method, qr/\A(?:show_)?$command\z/mxs,
         'correct command invoked on talk');
      shift @$args;    # Remove talk object itself
      is_deeply($args, $targets, 'talk method invoked with correct args');
   } ## end for my $targets ([], [qw( ciao a tutti )...
} ## end for my $command (qw( first last next previous attach detach ))

# show command requires slide number
for my $targets ([], [qw( ciao a tutti )]) {
   my $slide = int(rand 13);
   my $tstr = join(',', @$targets) || '';
   $input = "command=show slide=$slide target=$tstr\n";
   lives_ok { $object->execute_commands(undef, $talk) }
     "show remote command lives";
   is($output, "200 OK\n", "output for show (@$targets)");
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
   $input = "command=$command\n";
   lives_ok { $object->execute_commands(undef, $talk) }
     "$command remote command lives";
   is($output, "200 OK\n", "output for $command");
   my ($method, $args) = $talk->next_call();
   is($method, $command, 'correct command invoked on talk');
   is(scalar @$args, 1, "no arg passed to talk method $command");
} ## end for my $command (qw( clamp loose quit ))

# book
{
   my $code = 'WWW::Slides::Rocks';
   $input = "command=book code=$code\n";
   lives_ok { $object->execute_commands(undef, $talk) }
     'book remote command lives';
   is($output, "200 OK\n", 'output for book');
   my ($method, $args) = $talk->next_call();
   is($method,       'book', 'correct command invoked on talk');
   is(scalar @$args, 2,      'one arg passed to talk method book');
   is($args->[1],    $code,  'code received and passed correctly');
}

# get_current
{
   $input = "command=get_current\n";
   lives_ok { $object->execute_commands(undef, $talk) }
     'get_current remote command lives';
   is(
      $output,
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
   $input = "command=get_attendees\n";
   lives_ok { $object->execute_commands(undef, $talk) }
     'get_attendees remote command lives';

   my @output = split /\n/, $output;
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
   is($method, 'get_attendees_details', 'correct command invoked on talk');
   is(scalar @$args, 1, 'no arg passed to talk method get_current');
}

# inexistent command leads to 500 error
$input = "command=inexistent\n";
lives_ok { $object->execute_commands(undef, $talk) }
  'inexistent command does not bomb it all';
like($output, qr/\A500\s+/msx, 'error for inexistent command');

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

BEGIN {

   package TestController;
   {
      use strict;
      use warnings;
      use Object::InsideOut qw( WWW::Slides::Controller );

      my @input : Field : Get(Name  => '_input') : Arg(Name  => 'input');
      my @output : Field : Get(Name => '_output') : Arg(Name => 'output');

      sub get_input_chunk {
         my $self = shift;
         return ${$self->_input()};
      }

      sub output {
         my $self = shift;
         ${$self->_output()} = join '', @_;
      }
   }

} ## end BEGIN
1;

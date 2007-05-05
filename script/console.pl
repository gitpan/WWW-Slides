#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use Pod::Usage qw( pod2usage );
use Getopt::Long qw( :config gnu_getopt );
use version; my $VERSION = qv('0.0.4');
use English qw( -no_match_vars );
use Term::ReadLine;

use lib qw( ../lib );
use WWW::Slides qw( spawn_server );
use WWW::Slides::Client::TCP;


my %config = (
   hport     => 50505,
   cport     => 50506,
   chost     => 'localhost',
   must_book => 0,
);
GetOptions(
   \%config,                 'usage',
   'help',                   'man',
   'version',                'cport|control-port|P=i',
   'chost|control-host|H=s', 'hport|port|http-port|p=i',
   'must_book|must-book|b!', 'sfile|slides-file|s=s',
   'debug|d!',
);
pod2usage(message => "$0 $VERSION", -verbose => 99, -sections => '')
  if $config{version};
pod2usage(-verbose => 99, -sections => 'USAGE') if $config{usage};
pod2usage(-verbose => 99, -sections => 'USAGE|EXAMPLES|OPTIONS')
  if $config{help};
pod2usage(-verbose => 2) if $config{man};

# Script implementation here
my $spawned;
my $client = eval { WWW::Slides::Client::TCP->new(
   port => $config{cport},
   host => $config{chost},
) };
if ($EVAL_ERROR) {    # Auto-create if applicable
   if ($config{chost} =~/\A(?: localhost | 127.0.0.1 )\z/mxs) {
      my $slides = $config{sfile};
      $slides = \@ARGV if @ARGV;
      if (! defined $slides) {
         my $data = '';
         while (<DATA>) {
            last if /\A __END__ \s*\z/msx;
            $data .= $_;
         }
         $slides = \$data;
      }
      $spawned = spawn_server({
         slides => $slides,
         controller_port => $config{cport},
         http_port       => $config{hport},
         debug           => $config{debug},
         must_book       => $config{must_book},
      }) or die $!;
   }
   $client = WWW::Slides::Client::TCP->new(
      port => $config{cport},
      host => $config{chost},
   );
} ## end if (!$sock)

my $term   = Term::ReadLine->new('WWW::Slides controller');
my $prompt = 'WWW::Slides> ';
my $OUT = $term->OUT() || \*STDOUT;


# Main loop
my @attendees; # Global variable to handle attendees by num. id
print_list();
OUTER:
my $last = '';
my $requested_exit = 1;
while (defined(my $input = $term->readline($prompt))) {
   last if $input =~ /\A\s* bye \s*\z/mxs;
   $input = $last if $input =~ /\A\s*\z/;
   $last = $input;
   my $command = elaborate_command($input);
   print {$OUT} $client->send_command($command) if $command;
   $requested_exit = 0;
   last unless $client->is_alive();
   $requested_exit = 1;
   print_list();
}

if ($spawned && ! $requested_exit) {
   my $child = wait();
   print "child $child exited with status $?\n";
}

sub elaborate_command {
   my ($input) = @_;

   $input =~ s/\A\s+|\s+\z//g;
   return unless length $input;

   my ($command, @items) = split /\s+/, $input;
   my $full = "command=$command ";

   $full .= "slide=" . shift(@items) . ' ' if $command eq 'show';

   my $targetted = join ' | ', 
      qw( next previous first last detach attach show );
   my $target;
   if ($command =~ /\A(?: $targetted )\z/mxs) {
      $full .= 'target=' . join ',', map {
         (/\A\d+\z/ && $_ > 0 && $_ <= @attendees)
           ? $attendees[$_ - 1]->{id}
           : $_
      } @items;
      $full .= ' ';
      @items = ();
   } ## end if ($command =~ /\A(?: $targetted )\z/mxs)
   elsif ($command eq 'book') {
      $full .= ' code=' . shift(@items) . ' ';
   }

   return $full . " @items";
} ## end sub elaborate_command

sub print_list {
   print {$OUT} "\n";
   my $slide_no = $client->get_current();
   print {$OUT} "current slide: $slide_no\n";

   my $count = 0;
   for my $attendee ($client->get_attendees()) {
      my %data = %$attendee;
      print {$OUT} ++$count;
      print {$OUT} ": $data{id} ($data{peer_address}), ";
      print {$OUT}($data{is_attached} ? 'attached, ' : 'detached, ');
      print {$OUT} "slide $data{current_slide}\n";
   } ## end for my $attendee (@att)
} ## end sub print_list


__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html>
   <head>
      <title>WWW::Slides Sample presentation</title>
      <style>
         div.slide {
            border: 1px dotted #777;
            width: 640px;
            padding: 1em;
         }
         div.sx { float: left; display: inline; }
         div.dx { float: right; display: inline; }
         div.clear { clear: both; }
      </style>
   </head>
   <body>
   
   <div id="slide1" class="slide">
      <h1>WWW::Slides - Web Presentations</h1>
      <p>
         WWW::Slides is a simple system for serving slides on the web.
         Just save them as HTML files, with a few rules, and you'll be
         able to present them on the web, e.g. in a conference call!
      </p>
      <div class="sx">
         <img src="http://www.polettix.it/images/WWW-Slides/Goggles_Guy.png">
      </div>
      <div class="sx">
         <ul>
            <li>the basic idea</li>
            <li>how it works</li>
            <li>what you need</li>
         </ul>
      </div>
      <div class="clear"></div>
   </div>

   <div id="slide2" class="slide">
      <h1>The basic idea</h1>
      <div class="sx" style="width: 340px; padding: 0 1em;">
         <p>
         Showing slides means that a <em>speaker</em> controls what's on
         the <em>screen</em> of each talk attendee - yes, you're thinking
         about <em>push</em> technologies. Just note that a <em>push</em>
         can be faked by a very long <em>pull</em>!
         </p>
         <p>
         Combining <strong>HTTP Streaming</strong> and <strong>CSS</strong>
         it's possible to control what the browser renders at any given time:
         </p>
      </div>
      <div style="margin-left: 380px">
         <img src="http://www.polettix.it/images/WWW-Slides/fox.jpg">
      </div>
      <div class="sx">
         <ul>
            <li>
               <em>HTTP Streaming</em> means that the server does not
               close the HTTP connection, but keeps it open and sends
               some data from time to time, just to prevent the browser
               from timing out;
            </li>
            <li>
               each slide is put inside a single <tt>&lt;div&gt;</tt>
               with a unique id, so that we can refer to each slide
               by its div id.
               Decent CSS support is needed to ensure that slides can
               be hidden-shown by simply sending a suitable 
               <tt>&lt;style&gt;</tt> sequence regarding the right
               div
            </li>
         </ul>
      </div>

      <div class="clear"></div>
   </div>

   <div id="slide3" class="slide">
      <h1>How it works</h1>
      <div class="sx">
         <img src="http://www.polettix.it/images/WWW-Slides/WWW-Slides-SampleArch.png">
      </div>
      <div class="sx" style="width: 350px; padding: 0 1em;">
         <ul>
            <li>
               A main <em>Talk</em> server is started; it handles all
               the needed synchronisation stuff.
            </li>
            <li> 
               On the <em>Attendee</em> side, it listens to a
               given port for incoming HTTP requests from the browsers.
               When they connect, the currently selected slide is served
               and the connection kept open;
            </li>
            <li>
               On the <em>Speaker</em> side, there are various means to
               control the evolution of the presentation. One of the
               simplest is having the <em>Talk</em> as a standalone server
               accepting incoming TCP control connections on a given
               port.
            </li>
            <li>
               When the speaker issues a transition command (e.g. "go to the
               next slide"), the slide is sent to the clients using the
               still-open HTTP connections.
            </li>
         </ul>
      </div>
      <div class="clear"></div>
   </div>

   <div id="slide4" class="slide">
      <h1>What you need</h1>
      <div class="sx">
         <img src="http://www.polettix.it/images/WWW-Slides/toolkit.png">
      </div>
      <div class="sx" style="width: 410px">
         <ul>
            <li>
               As a <em>Curious</em>, you need to install
               WWW::Slides and use the example applications (there is
               a console-based one and a CGI-based one). Feedbacks
               welcome! 
            </li>
            <li>
               As a <em>Programmer</em>, you need to understand WWW::Slides 
               model and force me to write the documentation.
            </li>
            <li>
               As <em>Speaker</em>, you need to put up your slides in a
               more or less acceptable way. HTML files with not-too-fancy
               formatting should be good. Moreover, you should know
               in advance where your images will be placed, and use
               absolute links.
            </li>
            <li> 
               As an <em>Attendee</em>, you only need a browser with a
               decent support for CSS. And - probably - you should be
               able to HTTP-connect to non-standard ports.
            </li>
         </ul>
      </div>
      <div class="clear"></div>
   </div>

   <div id="slide5" class="slide">
      <h1>That's all folks!</h1>
      <div class="sx" style="width: 410px">
         <ul>
            <li>
               I know... it's a rather dumb idea,
               but it seems to work! Give me feedback at
               <a href="mailto:flavio@polettix.it">flavio@polettix.it</a>
               if you want.
            </li>
            <li>
               There are things that have not been included here:
               personalised transitions for each attendee (like they
               were looking at the slides in their hands instead of
               the screen), restricting access to authorised clients,
               etc. But it's all there, implemented!
            </li>
            <li>
               I wish to thank <a href="http://openclipart.org/">the Open Clip Art Library</a>
               and <a href="http://pdphoto.org/">PD Photo</a> for
               the images, 
               and <a href="http://perl.plover.com">Mark Jason Dominus</a>
               for <a href="http://perl.plover.com/yak/presentation/">his
               hints on preparing slides</a>.
            </li>
         </ul>
      </div>
      <div class="dx">
         <img src="http://www.polettix.it/images/WWW-Slides/gorilla.png">
      </div>

      <div class="clear"></div>
   </div>

  
   </body>
</html>


__END__
=head1 NAME

console.pl - demo script for WWW::Slides


=head1 VERSION

See version at beginning of script, variable $VERSION, or call

   shell$ console.pl --version


=head1 USAGE

   console.pl [--usage] [--help] [--man] [--version]

   console.pl [--control-port|-P <port>] [--control-host|-H <host>]
              [--http-port|-p <port>] [--must-book|-b]
              [--slides-file|-s <filename>]

  
=head1 EXAMPLES

   # Start it all, use defaults, auto-reconnect if possible
   shell$ console.pl

   # Ditto, but values on command line (these are equal to defaults)
   shell$ console.pl -P 50506 -H localhost -p 50505

   # Force booking of clients
   shell$ console.pl -b

   # Use custom slides instead of demo ones
   shell$ console.pl --slides-file slides.html


  
=head1 DESCRIPTION

This script is a simple demo of the WWW::Slides capabilities.

At the moment, WWW::Slides allows the creation of one or more talks that
can be served via HTTP. You can start a simplistic HTTP server on a port
of your choice, that allows browsers to connect in order to make them
show slides.

This console script starts the server for you if it's not already running,
otherwise it will reconnect to the existing one. Via the console you can
set various things on the server, e.g. which slide to show, if clients
are allowed to detach from the main served slide, and so on.

=head2 A Note On The Slides

The slide production is not the core target of WWW::Slides, despite its
name. There are plenty of html-slide production systems out there, and
they are surely all valid.

The basic working model in WWW::Slides is that each slide is contained
inside a separated HTML C<div> whose id is different from the others,
like this:

  <html>
    <head><title>The title...</title></head>
    <body>
      <div id="slide1">
         ...
      </div>

      <div id="slide2">
         ...
      </div>

      <div id="slide3">
         ...
      </div>

    </body>
  </html>

When a slide is sent to the client, two scenarios are possible:

=over

=item

the slide has never been sent to the client.

=item

the slide has already been sent to the given client.

=back

In the former case, the whole text for the C<div> is sent to the client,
in the latter the "cached" version is used. In both cases, the previous
slide is hidden setting its C<display> style to C<none>, and the new
one is I<activated> setting its C<display> style to C<block>. When all
slides have been sent, the slide transition is only a matter of hiding
and showing the right C<div>.

At the moment, there is a rudimentary reading mechanism to partition
an input HTML file into different I<interesting> sections:

=over

=item

a preamble, which is the HTML start including all head up to the opening
C<body> tag. Note that this tag should be on a line on its own;

=item

a slide for each C<div> encountered. Opening and closing of slide's C<div>s
should be on lines on their own.

=back

Slides will be numbered with an increasing numerical id as they are read
in input. You should ensure that each one has a different identifier. For
sake of consistency with the I<usual> slide numbering, the numerical ids
will start from one.

Slides reading will be hopefully made better in the future, possibly
with integration with specific slide production systems.


=head1 THE SERVER

The server part will be started automatically if the console is not able
to reconnect to a pre-existent one listening on the given port. By default,
some three slides bundled in this script will be served, just to show
the capabilities, but you can provide a slide file of your own via the
C<--slides-file|-s> option, like this:

   shell$ console.pl --slides-file slides.html
   shell$ console.pl -s slides.html

At the moment the C<slides.html> handling is very simplistic, take the
example in the __DATA__ section as an inspiration. Things will hopefully
change in the future.

The server accepts client browser connections on the port given with the
option C<--http-port|-p>, like this:

   shell$ console.pl --http-port 8080
   shell$ console.pl -p 8080

You can force the clients to give you a booking code when they enter, by
specifing the <--must-book|-b> option:

   shell$ console.pl --http-port 8080 --must-book

If this is the case, you can book clients from the console itself (see
following paragraph), and then clients must put the booking code as the
path in the provided URI. This will ease handling via automated scripts
and CGI, hopefully, providing a simple authorisation mechanism.

The server also listens to a given port for consoles to connect and send
commands. You can specify which port will be used for this using the
<--control-port|-H> option:

   shell$ console.pl --control-port 56789

NOTE: the server will *not* be started if the C<--control-host|-H> option
is set to something different from C<localhost> or C<127.0.0.1>.


=head1 THE CONSOLE

The console part is a simple way to send commands to the server part. You
can provide the address/port to connect to using the C<--control-host|-H>
and C<--control-port|-P> options:

   shell$ console.pl -H slides.example.com -P 56789

Note that if you provide a hostname different from C<localhost> or
C<127.0.0.1> the script will not start a server for you on the given
port.

Once you're inside the console, you are presented with the list of the
currently connected client browsers and a prompt, like this:

 current slide: 1
 1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
 2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
 WWW::Slides>

For each client, you find:

=over

=item

a numerical identifier that you can use in some of the commands detailed
later

=item

the client id (which is equal to the booking code if these codes are
used)

=item 

the address/port the client is connecting from

=item

the I<attachment> status, i.e. if the given client follows the slide
transition mechanism of the talk or not (more on this later).

=item

the slide number currently seen by the client.

=back

In the following, the client browser is usually referred to as I<attendee>.

=head2 Moving Around

You have five basic commands to move around the presentation:

=over

=item B<first>, B<last>

these commands set the slide on the first or last, respectively;

=item B<previous>, B<next>

go back a slide or to the next one. Note that you will not be able
to bo before the first slide or beyond the last one;

=item B<< show I<slide> >>

go to the specified I<slide>

=back

Every command also accepts the specification of the attendee(s) to which
the command applies. By default, it will be applied to the attached
ones (see later L<Attachment Status> for details). A sample session:

  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> next
  200 OK
  
  current slide: 2
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 2
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 2
  WWW::Slides> last
  200 OK
  
  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 3
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides> previous
  200 OK
  
  current slide: 2
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 2
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 2
  WWW::Slides> first
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> previous
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> last
  200 OK
  
  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 3
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides> next
  200 OK
  
  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 3
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides> show 1
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> show 2
  200 OK
  
  current slide: 2
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 2
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 2
  WWW::Slides>



=head2 Attachment Status

You can think about the talk as if there were a main screen where the
speaker projects the slides, while the attendees also have a printed
copy of the presentation available in their hands. Which one they are
seeing depends on their I<attachment> status.

When the attendee is I<attached>, the attendee is looking at the slide
on the main screen, i.e. is I<attached> to the speaker's talk. On the
other hand, when the attendee is I<detached> it means that she is looking
at the slides in her hands, and a slide transition on the main screen
will not change what the attendee is looking at.

The console has two commands to handle the attachment status: C<attach>
and C<detach>. By default, they work on all the attendees:


  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> detach
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), detached, slide 1
  WWW::Slides> attach
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides>

You can also provide either their numerical progressive id, or their
extended id:

  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), attached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> detach 1
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> detach 374b0e9038efb292
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), detached, slide 1
  WWW::Slides> attach 2
  200 OK
  
  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides>

As anticipated, when a client is detached it does not follow the main
talk:

  current slide: 1
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 1
  WWW::Slides> next
  200 OK
  
  current slide: 2
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 2
  WWW::Slides> next
  200 OK
  
  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides>

But you can let the attendee move around, of course:

  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 1
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides> next 1
  200 OK
  
  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 2
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides> next a0a51083f9f431e9
  200 OK
  
  current slide: 3
  1: a0a51083f9f431e9 (127.0.0.1:34254), detached, slide 3
  2: 374b0e9038efb292 (127.0.0.1:34257), attached, slide 3
  WWW::Slides>

The C<attach> command, of course, Does The Right Thing when re-attaching
an attendee, i.e. it forces her on the current slide.

If you want to prevent a client from detaching, you can use the C<clamp>
command. This will re-attach any detached client, and block them on the
talk's slide. You can then re-enable detaching with the C<loose> command.
These two commands work on a higher - i.e. talk - level and are not
specific per attendee.

=head2 Booking

You can book an attendee with the C<book> command, like this:

  WWW::Slides> book <identifier>

The client browser will then have to connect using the correct URI
including the I<identifier> in the path info. For example, if you
book the following:

  WWW::Slides> book my-client-1

and the server process is running on C<example.com:50505>, the URI to 
use for the connection will be:

  http://example.com:50505/my-client-1

The booking process is enabled only if the server was started with the
C<--must-book|-b> option.

=head2 Quitting

You have two choices to quit:

=over

=item

you can press CTRL-D and quit from the console, but leave the server
process running, or

=item

you can type C<quit> and force the server to exit as well.

=back

=head1 OPTIONS

=over

=item --control-port|-P <port>

set the port where the server is listening (or will listen, if the server
is auto-launched).

Defaults to 50506.

=item --control-host|-H <host>

set the host to connect to. If this option is either C<localhost> or
C<127.0.0.1> the server process will be launched if not existent.

Defaults to localhost.

=item --help

print a somewhat more verbose help, showing usage, this description of
the options and some examples from the synopsis.

=item --http-port|-p <port>

the port where the attendees can connect to in order to receive slides.

Defaults to 50505.

=item --man

print out the full documentation for the script.

=item --must-book|-b

sets if the booking mechanism should be used. See L<Booking>.

Default is that no booking necessary, any client can connect.

=item --slides-file|-s

sets the file from where the slides should be read.

By default slides are taken from the C<__DATA__> section of this script,
where there are some sample slides. You can mimic the structure of these
slides to produce yours.

=item --usage

print a concise usage line and exit.

=item --version

print the version of the script.

=back

=head1 DIAGNOSTICS

Any error in the server will be (usually) trapped and the text sent
to the connected console. This happens if the server succeeds to
reach the C<run> state, of course. In other cases, the error message
should be descriptive for itself.

I'm too lazy to detail possible error conditions for the console, sorry :)


=head1 CONFIGURATION AND ENVIRONMENT

console.pl requires no configuration files or environment variables.


=head1 DEPENDENCIES

Without WWW::Slides you won't go very far. Moreover, you will need
Term::ReadLine.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 AUTHOR

Flavio Poletti C<flavio@polettix.it>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Flavio Poletti C<flavio@polettix.it>. All rights reserved.

This script is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>
and L<perlgpl>.

Questo script è software libero: potete ridistribuirlo e/o
modificarlo negli stessi termini di Perl stesso. Vedete anche
L<perlartistic> e L<perlgpl>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NEGAZIONE DELLA GARANZIA

Poiché questo software viene dato con una licenza gratuita, non
c'è alcuna garanzia associata ad esso, ai fini e per quanto permesso
dalle leggi applicabili. A meno di quanto possa essere specificato
altrove, il proprietario e detentore del copyright fornisce questo
software "così com'è" senza garanzia di alcun tipo, sia essa espressa
o implicita, includendo fra l'altro (senza però limitarsi a questo)
eventuali garanzie implicite di commerciabilità e adeguatezza per
uno scopo particolare. L'intero rischio riguardo alla qualità ed
alle prestazioni di questo software rimane a voi. Se il software
dovesse dimostrarsi difettoso, vi assumete tutte le responsabilità
ed i costi per tutti i necessari servizi, riparazioni o correzioni.

In nessun caso, a meno che ciò non sia richiesto dalle leggi vigenti
o sia regolato da un accordo scritto, alcuno dei detentori del diritto
di copyright, o qualunque altra parte che possa modificare, o redistribuire
questo software così come consentito dalla licenza di cui sopra, potrà
essere considerato responsabile nei vostri confronti per danni, ivi
inclusi danni generali, speciali, incidentali o conseguenziali, derivanti
dall'utilizzo o dall'incapacità di utilizzo di questo software. Ciò
include, a puro titolo di esempio e senza limitarsi ad essi, la perdita
di dati, l'alterazione involontaria o indesiderata di dati, le perdite
sostenute da voi o da terze parti o un fallimento del software ad
operare con un qualsivoglia altro software. Tale negazione di garanzia
rimane in essere anche se i dententori del copyright, o qualsiasi altra
parte, è stata avvisata della possibilità di tali danneggiamenti.

Se decidete di utilizzare questo software, lo fate a vostro rischio
e pericolo. Se pensate che i termini di questa negazione di garanzia
non si confacciano alle vostre esigenze, o al vostro modo di
considerare un software, o ancora al modo in cui avete sempre trattato
software di terze parti, non usatelo. Se lo usate, accettate espressamente
questa negazione di garanzia e la piena responsabilità per qualsiasi
tipo di danno, di qualsiasi natura, possa derivarne.

=cut

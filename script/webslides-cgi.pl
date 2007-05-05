#!/opt/perl/bin/perl
# Put your own correct shebang line above!!!

use strict;
use warnings;
use CGI qw( :standard );
use English qw( -no_match_vars );
use version; my $VERSION = qv('0.0.5');
use WWW::Slides::Client::TCP;
use WWW::Slides qw( spawn_server );

my %config = (
   hport => 50505,
   hhost => 'localhost',
   cport => 50506,
   chost => 'localhost',
);

# Script implementation here
# Try to connect to an existing presentation on given command port...
my $client = eval { get_client() };

# Command execution pre-check, either for quit or start
my $command = param('command') || '';
if ($command eq 'quit') {
   $client->quit() if $client;
   $client = undef;
}
elsif ((!$client) && ($command eq 'start')) {
   start_server();
   $client = get_client(); # Re-try to connect
} ## end elsif ((!$client) && ($command...

# Other commands execution and page rendering
print_starter();
if (!$client) {
   print qq{<p><a href="?command=start">Start</a></p>};
}
else {
   my $outcome = execute_commands();
   my ($slide_number, $total_slides) = $client->get_current();

   print_navigation_bar($slide_number, $total_slides);
   print {*STDOUT} "<br />last command: $outcome\n<br />" if $outcome;
   print_attendees_list($total_slides);
   print {*STDOUT} qq{<p>Serving slides }
      . qq{<a href="http://$config{hhost}:$config{hport}/" target="_blank">}
      . qq{here</a></p>\n};
} ## end else [ if (!$client)
print end_html();

#-----------  FUNCTIONS  --------------------------------------------------

sub get_client {
   return WWW::Slides::Client::TCP->new(
      port => $config{cport},
      host => $config{chost},
   );
} ## end sub get_client

sub transition_display {
   my ($slide_number, $total, $code) = @_;
   return join ' ', linked_command('first', '«', target => $code),
     linked_command('previous', '&lt;', target => $code), qq{
         <form style="display: inline">
            <input type="hidden" name="command" value="show">
            <input type="hidden" name="target" value="$code" >
            <input type="text" name="slide" value="$slide_number" size="4">
         </form> / $total
     }, linked_command('next', '&gt;', target => $code),
     linked_command('last', '»', target => $code);
} ## end sub transition_display

sub execute_commands {
   my $command = param('command') or return;
   my %actions = (
      'targetted' => sub {
         my @targets = split /,/, param('target') || '';
         my $cmd = $client->can($command) or return;
         $client->$cmd(@targets);
      },
      'quit' => sub { return $client->quit(); sleep 1; },
      'show' => sub {
         my $slide_no = param('slide') || 1;
         my @targets = split /,/, param('target') || '';
         $client->show($slide_no, @targets);
      },
   );
   $actions{$_} = $actions{targetted} for qw(
     first last previous next attach detach
   );
   return unless exists $actions{$command};
   return $actions{$command}->();
} ## end sub execute_commands

sub linked_command {
   my ($command, $name, %params) = @_;
   $name = $command unless defined $name;
   my $cmd = join ';', "command=$command", map {
      my $value = $params{$_};
      my $val = ref($value) ? join(',', @$value) : $value;
      "$_=$val";
   } keys %params;
   return qq{<a href="?$cmd">$name</a>};
} ## end sub linked_command

sub print_starter {
   my $refresh_uri = url();
   print {*STDOUT} header(),
     start_html(
      -title => "WWW::Slides Controller",
      -head  =>
        meta({-http_equiv => 'refresh', -content => "10; $refresh_uri"})
     ),
     h1('WWW::Slides Controller');

} ## end sub print_starter

sub print_navigation_bar {
   my ($slide_number, $total_slides) = @_;
   print {*STDOUT}
     qq{<a href="?">Refresh</a> <a href="?command=quit">Quit</a> - };
   print {*STDOUT} transition_display($slide_number, $total_slides);
} ## end sub print_navigation_bar

sub print_attendees_list {
   my ($total_slides) = @_;

   my @attendees = $client->get_attendees();
   if (@attendees) {

      print {*STDOUT} p('Connected attendees...');
      print {*STDOUT} <<"END_OF_TABLE_START" ;
         <table border=1>
            <tr>
               <td>Id</td>
               <td>Address</td>
               <td>Status</td>
               <td>Slide</td>
            </tr>
END_OF_TABLE_START

      my $count = 0;
      for my $attendee ($client->get_attendees()) {
         ++$count;
         my ($attach, $slide);
         if ($attendee->{is_attached}) {
            $attach =
                'attached ('
              . linked_command('detach', undef, target => $attendee->{id})
              . ')';
            $slide = "$attendee->{current_slide} / $total_slides";
         } ## end if ($attendee->{is_attached...
         else {
            $attach =
                'detached ('
              . linked_command('attach', undef, target => $attendee->{id})
              . ')';
            $slide = transition_display($attendee->{current_slide},
               $total_slides, $attendee->{id});
         } ## end else [ if ($attendee->{is_attached...
         print {*STDOUT} <<"END_OF_TABLE_LINE" ;
            <tr>
               <td>$count</td>
               <td>$attendee->{peer_address}</td>
               <td>$attach</td>
               <td>$slide</td>
            </tr>
END_OF_TABLE_LINE

      } ## end for my $attendee ($client...
      print {*STDOUT} "\n   </table>\n";
   } ## end if (@attendees)
   else {
      print {*STDOUT} "<p>no one is connected...</p>\n";
   }
} ## end sub print_attendees_list

sub start_server {
   return unless $config{chost} =~ /\A(?: localhost | 127.0.0.1 )\z/mxs;

   my $slides = $config{sfile};
   $slides = \@ARGV if @ARGV;
   if (!defined $slides) {
      my $data = '';
      while (<DATA>) {
         last if /\A __END__ \s*\z/msx;
         $data .= $_;
      }
      $slides = \$data;
   } ## end if (!defined $slides)
   spawn_server(
      {
         slides          => $slides,
         controller_port => $config{cport},
         http_port       => $config{hport},
         debug           => $config{debug},
         must_book       => $config{must_book},
      }
     )
     or die "could not spawn server: $!";
} ## end sub start_server

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
            padding: 0 1em 1em 1em;
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
         We're going to see...
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

webslides-cgi.pl - demo CGI script for WWW::Slides


=head1 INSTALLATION AND USAGE

Installation is straighforward:

=over

=item

put the script into your cgi-bin directory, with correct permissions
(e.g. execution);

=item

B<change the shebang line>, the provided one will almost surely fail for
you;

=item

if you haven't installed the modules, put the necessary C<use lib '...';>
commands;

=item

enjoy :)

=back


=head1 DESCRIPTION

This CGI implements a sub-set of the commands accessible via console.pl.

If no slide server is listening on the given command port, you will see
a plain page with the option to start one. You know where you should
click.

If the CGI succeeds in connecting to an existing slide server, you will
be presented with a rich*COUGH*basic interface to do something.

On the top you find the main speaker controls:

=over

=item Refresh

you can trigger a page refresh, even if it auto-refreshes every 10 seconds;

=item Quit

to quit the presentation (shuts the slide server down);

=item transition handles

with which you can go to the first, previous, exact, next, last slide.

=back

Just below this navigation you'll find the list of connected attendees,
if any. When an attendee is "attached" the slide number will be equal
to that set by the speaker above. If you "detach" an attendee you will
enable a per-attendee micro-menu with the same options as above (for
transitions only). You'll be able to sort it out.

See documentation for console.pl for further details.
  

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


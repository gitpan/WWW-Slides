#!/opt/perl/bin/perl
use strict;
use warnings;
use CGI qw( :standard );
use English qw( -no_match_vars );
use version; my $VERSION = qv('0.0.4');
use WWW::Slides::Client::TCP;

my %config = (
   hport   => 50505,
   cport   => 50506,
   chost   => 'localhost',
);

# Script implementation here
my $client = eval {
   WWW::Slides::Client::TCP->new(
      port => $config{cport},
      host => $config{chost},
   );
};
if ($EVAL_ERROR) {    # Auto-create if applicable
   spawn_server()
     if $config{chost} =~ /\A(?: localhost | 127.0.0.1 )\z/mxs;
   $client = WWW::Slides::Client::TCP->new(
      port => $config{cport},
      host => $config{chost},
   );
} ## end if ($EVAL_ERROR)

# Honor commands
my $outcome = execute_commands();

# Print out situation and handles
print {*STDOUT} header(), start_html("Simple WWW::Slides Controller");

print "last command: $outcome\n<hr>\n" if $outcome;
print qq{<a href="?">Home</a><br />\n};

my $slide_number = $client->get_current();
print {*STDOUT} join ' ', linked_command('first'),
  linked_command('previous'), $slide_number, linked_command('next'),
  linked_command('last');

print {*STDOUT} "
   <table border=1>
      <tr>
         <td>Id</td>
         <td>Address</td>
         <td>Status</td>
         <td>Slide</td>
      </tr>
";
my $count = 0;
for my $attendee ($client->get_attendees()) {
   ++$count;
   my $attach;
   if ($attendee->{is_attached}) {
      $attach =
        'attached ('
        . linked_command('detach', target => $attendee->{id}) . ')';
   }
   else {
      $attach =
        'detached ('
        . linked_command('attach', target => $attendee->{id}) . ')';

   } ## end else [ if ($attendee->{is_attached...
   print {*STDOUT} "
      <tr>
         <td>$count</td>
         <td>$attendee->{peer_address}</td>
         <td>$attach</td>
         <td>$attendee->{current_slide}</td>
      </tr>
   ";
} ## end for my $attendee ($client...
print {*STDOUT} "\n   </table>\n", linked_command('quit');

print end_html();

sub execute_commands {
   my $command = param('command') or return;
   my %actions = (
      'targetted' => sub {
         my @targets = split /,/, param('target') || '';
         my $cmd = $client->can($command) or return;
         $client->$cmd(@targets);
      },
      'quit' => sub { return $client->quit(); sleep 1; }
   );
   $actions{$_} = $actions{targetted} for qw(
      first last previous next attach detach
   );
   return unless exists $actions{$command};
   return $actions{$command}->();
}

sub linked_command {
   my ($command, %params) = @_;
   my $cmd = join ';', "command=$command", map {
      my $value = $params{$_};
      my $val = ref($value) ? join(',', @$value) : $value;
      "$_=$val";
   } keys %params;
   return qq{<a href="?$cmd">$command</a>};
} ## end sub linked_command

sub spawn_server {
   my $pid = fork();
   die "could not fork(): $!" unless defined $pid;
   sleep(1) && return if $pid;    # father

   require WWW::Slides::SlideShow;
   require WWW::Slides::Talk;
   require WWW::Slides::Controller::STDIO;
   require WWW::Slides::Controller::TCP;
   require POSIX;

   # Daemonise
   chdir '/';
   close STDOUT;
   close STDERR;
   close STDIN;
   POSIX::setsid() or die "setsid: $!";
   $SIG{PIPE} = 'IGNORE'; # Dunno why, but...

   # On with the (slide)show
   my $slide_show = WWW::Slides::SlideShow->new();
   $slide_show->read($config{sfile} || \*DATA);

   my $controller =
     WWW::Slides::Controller::TCP->new(port => $config{cport});

   my $talk = WWW::Slides::Talk->new(
      controller => $controller,
      port       => $config{hport},
      slide_show => $slide_show,
      must_book  => $config{must_book},
   );
   $talk->run();

   exit 0;
} ## end sub spawn_server

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html>
   <head>
      <title>Here I come!</title>
   </head>
   <body>

        <div id="slide0">
            <h1>This is slide 1</h1>
Here you can find the contents for slide #1. You can insert images:
<p>
<img src="http://www.polettix.it/cgi-bin/wiki.pl/download/PerlFlowers.png"
     alt="Perl flowers" title="Perl flowers">
<p>as well as other elements:
<ul>
<li>a</li>
<li>simple</li>
<li>list</li>
</ul>

         </div>

        <div id="slide1">

<h1>This is slide 2</h1>
The contents are completely different here.
<hr>
<p>
<img src="http://www.polettix.it/cgi-bin/wiki.pl/download/Soffietto-soluzione.png"
     alt="solution" title="solution">

         </div>

        <div id="slide2">

<h1>This is slide 3</h1>
The contents are completely different here, with respect to the other
two pages.
<hr>
<p>
<img src="http://www.polettix.it/cgi-bin/wiki.pl/download/Casa.png"
     alt="solution" title="solution">
<p>I live here!

         </div>

   </body>
</html>

__END__

=head1 NAME

webslides-cgi.pl - demo CGI script for WWW::Slides


=head1 USAGE

Put into your cgi-bin directory, adjust paths if you haven't installed
the modules and go!

=head1 DESCRIPTION

This CGI implements a sub-set of the commands accessible via console.pl.
See documentation for console.pl.
  

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



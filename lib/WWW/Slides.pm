package WWW::Slides;

use version; our $VERSION = qv('0.0.4');

use warnings;
use strict;
use Carp;
use base 'Exporter';
use Scalar::Util qw( blessed );

our @EXPORT    = qw();
our @EXPORT_OK = qw( spawn_server );

# Module implementation here

sub _launch_server {
   my %config = %{$_[0]};

   # Prepare and run
   if (!exists $config{talk}) {
      if (blessed $config{slides}) {
         $config{slide_show} = $config{slides};
      }
      else {
         require WWW::Slides::SlideShow;
         $config{slide_show} = WWW::Slides::SlideShow->new();
         $config{slide_show}->read($config{slides});
      }

      if (!exists $config{controller}) {
         require WWW::Slides::Controller::TCP;
         $config{controller} =
           WWW::Slides::Controller::TCP->new(
            port => $config{'controller_port'},);
      } ## end if (!exists $config{controller...

      if ($config{debug} && !exists $config{logger}) {
         require WWW::Slides::BasicLogger;
         $config{logger} =
           WWW::Slides::BasicLogger->new(channel => \*STDERR);
      }

      # Ensure a couple of defaults
      $config{accepts_detaches} = 1
        unless exists $config{accepts_detaches};
      $config{ping_interval} ||= 10;
      $config{port} = $config{http_port};

      require WWW::Slides::Talk;
      $config{talk} = WWW::Slides::Talk->new(%config);
   } ## end if (!exists $config{talk...

   # Daemonise
   require POSIX;
   POSIX::setsid();    # not a must IMHO: or die "setsid: $!";
   chdir '/';
   close STDOUT;
   close STDERR unless $config{debug};
   close STDIN;
   $SIG{PIPE} = 'IGNORE';    # For stray connections

   # Run talk
   $config{talk}->run();

   exit 0;
} ## end sub _launch_server

sub spawn_server {
   my ($config_href) = @_;
   croak "expected HASH ref as input parameter"
     unless ref($config_href) eq 'HASH';
   my %config = %$config_href;

   # First, let's see if we have all we need, which is little
   if (!exists $config{talk}) {
      croak "nowhere to take the slides from, provide a 'slides' parameter"
        unless exists $config{slides};

      croak "please provide either a 'controller' or a 'controller_port'"
        unless exists($config{controller})
        || exists($config{controller_port});

      croak "please provide an 'http_port' to listen to"
        unless $config{http_port};
   } ## end if (!exists $config{talk...

   # Here the iato comes
   my $pid = fork();
   die "could not fork(): $!"  unless defined $pid;    # error
   _launch_server($config_href) unless $pid;            # child
   sleep(1);                                           # father
   return $pid;
} ## end sub spawn_server

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides - serve presentations on the Web


=head1 VERSION

This document describes WWW::Slides version 0.0.4


=head1 SYNOPSIS

   # It can be as simple as this:
   use WWW::Slides qw( spawn_server );
   my $pid = spawn_server(
      {
         slides          => \@slide_filenames, 
         http_port       => 50505,
         controller_port => 50506,
      }
   );

    
  
  
=head1 DESCRIPTION

This module will eventually be a facade for using the variuous modules
available in this library. For this reason, this module will mainly be
function-oriented.

=head2 Spawning Servers

The C<spawn_server()> sub will spawn a talk for you, providing sensible
defaults. You can override each of them, of course. The spawned server
is a daemon, with root directory set to C</>, closed filehandles, etc.

You can provide your fully built WWW::Slides::Talk object (or equivalent)
to the function; in this case, you're only actually using the
I<daemonising> property of the function itself.

It's much easier to use the function with a minimum of required parameters
and let the code do its work, though. At the very basic level, you should
provide at least the following parameters:

=over

=item slides

the slides to serve. The easier approach here is pass a reference to an
array of filenames of HTML files, and let the code load them and figure
out how to put them into separated slides.

=item http_port

where the server should listen for incoming connections from browsers.

=item controller_port

where the server should listen for incoming TCP connections from
speakers.

=back


So, the basic invocation is as simple as this:

   use WWW::Slides qw( spawn_server );
   my $pid = spawn_server(
      {
         slides          => \@slide_filenames, 
         http_port       => 50505,
         controller_port => 50506,
      }
   );

In this case, browsers should point to C<http://server.address:50505/>
and speakers should connect to port C<50506>. That's it.

The WWW::Slides system has a minimum integration with a logging system.
It should work seamlessly with Log::Log4perl, but you're not obliged to
use it; if you don't have it, it's ok even if you want to actually
log something, because there is a minimal implementation of the relevant
part of Log::Log4perl. If you have a C<$logger> object that conforms to
Log::Log4perl (and it's easy to conform to it), you can pass it and
have logs sent to it:

   use WWW::Slides qw( spawn_server );
   use Log::Log4perl qw( get_logger );
   # ... initialise Log::Log4perl...

   my $logger = get_logger();
   my $pid = spawn_server(
      {
         slides          => \@slide_filenames, 
         http_port       => 50505,
         controller_port => 50506,
         logger          => $logger,
      }
   );

In case all you want is to send log messages on standard error, just
say that you want to C<debug> and the code will happily build up a
logger for you behind the scenes:

   use WWW::Slides qw( spawn_server );
   my $pid = spawn_server(
      {
         slides          => \@slide_filenames, 
         http_port       => 50505,
         controller_port => 50506,
         debug           => 1,
      }
   );

See all the options for C<spawn_server> in the L<INTERFACE> section.


=head1 INTERFACE 

=head2 B<my $pid = spawn_server($config_hash_ref);>

This function lets you spawn a Talk server with a minimum of energy.
The server 'daemonizes' itself, avoiding the double-fork but making
all the other steps (changing the current directory, calling setsid(),
closing handles, etc.).

It gets its parameters through an hash reference containing them. 
The parameters are listed in the following list, note that those
indicated as 'mandatory' are not actually mandatory, because they
will be ignored if the C<talk> parameter is provided.


=over

=item accepts_detaches

When unset, the talk server will not accept detaches, i.e. all attendees
will stick to the main slide served by the talk.

On the other hand, when users can detach and actually detach themselves,
they do not follow the "mainstream" presentation, but can wander on their
own.

This parameter is optional, defaults to true.


=item controller

If you provide a controller, this controller should adhere to the
controller interface in WWW::Slides::Controller::Single. If you just
need to have a TCP controller, skip this parameter and let the sub
do its work, setting the TCP port with the C<controller_port> parameter.
On the other hand, if you have your smart controller go ahead.

Either this or C<controller_port> are mandatory.


=item controller_port

If all you need is just a basic TCP-based controller, fill in this
parameter with the port the controller should bind to, it's all that
you need. WWW::Slides::Controller::TCP will be invoked for you behind
the scenes.

Either this or C<controller> are mandatory.


=item debug

When set, STDERR will not be closed and a suitable logger will be built
for you if you don't provide one.


=item http_port

This parameter sets the port to which the spawned server will listen
for incoming connections from browsers.

It is mandatory.


=item logger

You can pass a reference to a logger object, e.g. a Log::Log4perl object.

This parameter is optional. Defaults to 'no logger' unless C<debug>
is set, in which case a logger is built up for you to log on STDERR.


=item must_book

When set, the spawned server will accept only client connections for
booked attendees. See L<WWW::Slides::Talk> for details.

This parameter is optional and defaults to false.


=item ping_interval

At least every C<ping_interval> some data are sent to the client
browser, in order to keep the TCP connection up.

This parameter is optional, default is 10 seconds.


=item slides

You can pass variuos things through this parameter:

=over

=item

an object conforming to the WWW::Slides::SlideShow interface;

=item

a filehandle;

=item

a filename;

=item

a reference to an array of filenames.

=back

In the last three cases, a WWW::Slides::SlideShow object will be built
up behind the scenes, and the parameter will be passed to the C<read()>
method. Refer to L<WWW::Slides::SlideShow> for details about it.

This parameter is mandatory.


=item talk

if you provide this parameter, you don't have to provide anything else
(except C<debug>, if you want). This is the object that will be used
as talk, most probably a WWW::Slides::Talk or something with a C<run()>
method. In this case, you take all the burden of building up a suitable
talk.


=back


=head1 DIAGNOSTICS

The functions will balk (ehr, C<croak>) at you if you don't provide
enough parameters or something wrong happens. The given error should
be meaningful by itself.


=head1 CONFIGURATION AND ENVIRONMENT

WWW::Slides requires no configuration files or environment variables.


=head1 DEPENDENCIES

WWW::Slides has virtually no dependency by itself, apart the non-core
semi-standard module C<version>. If you let the
functions do their work automatically, you will probably bump into
the dependencies of the various modules in the WWW::Slides distribution.



=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 AUTHOR

Flavio Poletti  C<< <flavio [at] polettix [dot] it> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Flavio Poletti C<< <flavio [at] polettix [dot] it> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>
and L<perlgpl>.

Questo modulo è software libero: potete ridistribuirlo e/o
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

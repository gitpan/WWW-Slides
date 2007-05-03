package WWW::Slides::Talk;
{
   use warnings;

   #   use diagnostics;
   use strict;
   use Carp;
   use version; our $VERSION = qv('0.0.4');
   use Object::InsideOut;
   use IO::Socket;
   use IO::Select;
   use English qw( -no_match_vars );

   use WWW::Slides::Attendee;
   use WWW::Slides::SlideTracker;

   # Other recommended modules (uncomment to use):
   #  use IO::Prompt;
   #  use Perl6::Export;
   #  use Perl6::Slurp;
   #  use Perl6::Say;
   #  use Regexp::Autoflags;
   #  use Readonly;

   #--------------------------------------------------------------------
   #
   # Member variables and initialisation
   #
   my @controller : Field    # Entry point for talk control
     : Std(Name => 'controller')
     : Arg(Name => 'controller', Mandatory => 1);

   my @door : Field          # Entry point for talk "listening"
     : Std(Name => 'door', Private => 1);
   my @port : Field          # Port used for talk TCP socket
     : Std(Name => 'port', Private => 1)
     : Arg(Name => 'port', Mandatory => 1);
   my @attendees : Field     # List of registered attendees
     : Std(Name => 'attendees', Private => 1);
   my @must_book : Field     # Should attendee book before entering?
     : Std(Name => 'must_book', Private => 1) : Get(Name => 'must_book')
     : Arg(Name => 'must_book', Default => 0);
   my @booked : Field        # Track expected attendees
     : Std(Name => 'booked', Private => 1)
     : Get(Name => 'booked', Private => 1);
   my @accepts_detaches : Field    # Attendees can detach
     : Std(Name => 'accepts_detaches', Private => 1)
     : Get(Name => 'accepts_detaches')
     : Arg(Name => 'accepts_detaches', Default => 1);

   my @slide_show : Field          # Where we're getting the slides from
     : Std(Name => 'slide_show', Private => 1)
     : Get(Name => 'slide_show', Private => 1)
     : Arg(Name => 'slide_show', Mandatory => 1);
   my @tracker : Field             # Track current slide
     : Std(Name => 'tracker', Private => 1)
     : Get(Name => 'tracker', Private => 1);

   my @ping_interval : Field       # Anti-timeout
     : Std(Name => 'ping_interval')
     : Arg(Name => 'ping_interval', Default => 60);
   my @alive : Field               # Is this talk still alive?
     : Std(Name => 'alive', Private => 1)
     : Get(Name => 'is_alive', Private => 1);
   my @selector : Field            # For select() operations
     : Std(Name => 'selector', Private => 1);

   my @logger : Field              # Where to send any log message
     : Std(Name => 'logger', Private => 1) : Get(Name => 'logger')
     : Arg(Name => 'logger');

   sub _init : Init {
      my $self = shift;
      my ($args) = @_;

      # Ensure there's a logger, even a fake one
      if (! $self->logger()) {
         require WWW::Slides::BasicLogger;
         $self->set_logger(WWW::Slides::BasicLogger->new(fake => 1));
      }

      my $door = IO::Socket::INET->new(
         Proto     => 'tcp',
         LocalPort => $self->get_port(),
         ReuseAddr => 1,
         Listen    => 3,
        )
        or croak "could not create door socket on port ",
        $self->get_port();
      $self->set_door($door);

      my $selector = IO::Select->new($door);
      $self->set_selector($selector);

      my $controller = $self->get_controller();
      $controller->set_selector($selector);

      $self->set_attendees({});    # Empty talk at the beginning
      $self->set_booked({}) if $self->must_book();

      $self->set_tracker(          # Auto-places on the first slide
         WWW::Slides::SlideTracker->new(
            slide_show => $self->get_slide_show()
         )
      );

      $self->set_alive(1);


      return;
   } ## end sub _init :
     #---------------------------------------------------------------------

   sub run {    # main loop function
      my $self       = shift;
      my $door       = $self->get_door();
      my $selector   = $self->get_selector();
      my $controller = $self->get_controller();

      $self->logger()->info('run(): entering main loop');
      while ($self->is_alive() && $controller->is_alive()) {
         my @ready = $selector->can_read($self->get_ping_interval());
         $self->ping();

         for my $fh (@ready) {    # Do all the work
            if ($controller->owns($fh)) {
               $self->execute_commands($fh);
            }
            elsif ($fh == $door) {
               $self->welcome_attendee();
            }
            else {
               $self->check_attendee($self->get_attendee($fh));
            }
         } ## end for my $fh (@ready)
      } ## end while ($self->is_alive() ...

      $self->logger()->info('run() exited from loop, talk ',
         ($self->is_alive() ? 'alive' : 'dead'),
         ', controller ',
         ($controller->is_alive() ? 'alive' : 'dead')
      );
      $self->cleanup();

      return;
   } ## end sub run

   sub cleanup : Private {
      my $self = shift;
      $self->logger()->debug('cleanup()');
      $self->remove_attendee($_) for $self->get_all_attendees();
      return;
   }

   # Attendees selection
   sub get_attached_attendees {
      my $self = shift;
      return grep { $_->is_attached() } $self->get_all_attendees();
   }

   sub get_all_attendees {
      my $self = shift;
      return values %{$self->get_attendees()};
   }

   sub resolve_attendees {
      my $self = shift;
      return map { ref $_ ? $_ : $self->get_attendee($_) } @_;
   }

   sub get_attendee {
      my $self = shift;
      my ($id) = @_;

      my $attendees = $self->get_attendees();
      if (ref $id) {    # It's a filehandle
         die "unexpected attendee's filehandle [$id]"
           unless exists $attendees->{$id};
         return $attendees->{$id};
      }

      # It's an external identifier
      for my $attendee (values %$attendees) {
         return $attendee if $attendee->id() eq $id;
      }
      die "could not find id $id";
   } ## end sub get_attendee

   # Content sending management
   sub broadcast : Private {
      my $self      = shift;
      my $command   = shift;
      my @attendees = @_
        ? $self->resolve_attendees(@_)
        : $self->get_all_attendees();

      # Ensure that $command is a reference to a sub
      if ((ref($command) || '') ne 'CODE') {    # Auto-define sub
         my ($cmd, @args) = ref $command ? @$command : $command;
         $command = sub {
            my $attendee = shift;
            my $method   = $attendee->can($cmd);
            $attendee->$method(@args) if $method;
            return;
         };
      } ## end if ((ref($command) || ...

      return map { $command->($_) } @attendees;
   } ## end sub broadcast :

   sub ping {    # Remind them all to remain awake
      return shift->broadcast('ping');
   }

   sub get_show_attendees {
      my $self = shift;
      return @_ if @_;
      return $self->get_attached_attendees();
   }

   # Transition commands, default to attached attendees
   sub show {    # Set specific slide
      my $self     = shift;
      my $slide_no = shift;

      if (! $self->slide_show()->validate_slide_id($slide_no)) {
         $self->logger()->error("show(): invalid slide $slide_no");
         return;
      }
      
      if (@_) {
         $self->logger()->debug("show(): going to slide $slide_no "
            . 'for some attendees only');
      }
      else {
         $self->logger()->debug("show(): going to slide $slide_no");
         $self->tracker()->goto($slide_no);
      }
      
      if (my @attendees = $self->get_show_attendees(@_)) {
         return $self->broadcast(['show', $slide_no], @attendees);
      }
      $self->logger()->debug('show(): no attendee found');
      return;
   } ## end sub show

   sub constrained_show : Private { # Factorised transition
      my $self = shift;
      my $bare = shift;
      my $method = 'show_' . $bare;

      if (@_) {
         $self->logger()->debug($method . '() for some attendees');
      }
      else {
         my $tracker = $self->tracker();
         $tracker->can('goto_' . $bare)->($tracker); # Call method OO-style
         $self->logger()->debug($method . '()');
      }
      
      if (my @attendees = $self->get_show_attendees(@_)) {
         return $self->broadcast($method, @attendees);
      }
      $self->logger()->debug($method . '(): no attendee found');
      return;
   }

   sub show_first {
      my $self = shift;
      return $self->constrained_show('first', @_);
   } ## end sub show_first

   sub show_last {
      my $self = shift;
      return $self->constrained_show('last', @_);
   } ## end sub show_last

   sub show_next {
      my $self = shift;
      return $self->constrained_show('next', @_);
   } ## end sub show_next

   sub show_previous {
      my $self = shift;
      return $self->constrained_show('previous', @_);
   } ## end sub show_previous

   # Command execution
   sub execute_commands : Private {
      my ($self, $fh) = @_;
      $self->get_controller()->execute_commands($fh, $self);
      return;
   }

   sub welcome_attendee : Private {
      my $self = shift;
      my $logger = $self->logger();

      $logger->debug('welcome_attendee(): accept()-ing new attendee');
      my $handle = $self->get_door()->accept()
        or croak("accept(): $OS_ERROR");
      $logger->debug("welcome_attendee(): $handle");

      # This also serves the first slide to the connected user
      $logger->debug('welcome_attendee(): creating object for new attendee');
      my $attendee = WWW::Slides::Attendee->new(
         handle        => $handle,
         slide_show    => scalar $self->get_slide_show(),
         current_slide => scalar $self->tracker->current(),
         check_booking => $self->must_book(),
      );

      # Register attendee
      $self->get_attendees()->{$handle} = $attendee;
      $self->get_selector()->add($handle);

      return;
   } ## end sub welcome_attendee :

   sub remove_attendee : Private {
      my $self       = shift;
      my ($attendee) = @_;
      my $handle     = $attendee->get_handle();

      $self->logger()->debug('removing attendee');
      $self->get_selector()->remove($handle);
      delete $self->get_attendees()->{$handle};

      $attendee->shut_down();
      return;
   } ## end sub remove_attendee :

   sub check_attendee : Private {
      my $self = shift;
      my ($attendee) = @_;

      my $is_alive;
      if ($attendee->must_check_booking()) {
         my $code = $attendee->booking_code();
         $is_alive = delete($self->booked()->{$code}) if defined $code;
         $attendee->book_ok() if $is_alive;
      }
      else {
         $is_alive = $attendee->handle_input();
      }

      $self->remove_attendee($attendee) unless $is_alive;
      return;
   } ## end sub check_attendee :

   sub book {
      my $self = shift;
      my ($code) = @_;
      $self->logger()->debug("book(): booking with code $code");
      $self->booked()->{$code} = 1;
      return;
   } ## end sub book

   sub quit {
      my $self = shift;
      $self->logger()->debug("quit() requested");
      $self->set_alive(0);
      return;
   }

   sub attach {
      my $self    = shift;
      my $current = $self->tracker()->current();
      $self->logger()->debug("attach()");
      return $self->broadcast(
         sub {
            my $attendee = shift;
            $attendee->attach();
            $attendee->show($current);
            return;
         },
         @_
      );

      return;
   } ## end sub attach

   sub detach {
      my $self = shift;
      return unless $self->accepts_detaches();
      $self->logger()->debug("detach()");
      return $self->broadcast(
         sub {
            shift->detach();
            return;
         },
         @_
      );
   } ## end sub detach

   sub clamp {
      my $self = shift;
      $self->logger()->debug("clamp()");
      $self->set_accepts_detaches(0);
      $self->attach();
      return;
   } ## end sub clamp

   sub loose {
      my $self = shift;
      $self->logger()->debug("loose()");
      $self->set_accepts_detaches(1);
      return;
   }

   sub get_current { return shift->tracker()->current(); }

   sub get_attendees_details {
      my $self = shift;
      return $self->broadcast(
         sub {
            my $attendee = shift;
            return {
               is_attached   => $attendee->is_attached(),
               id            => $attendee->id(),
               current_slide => $attendee->tracker()->current(),
               peer_address  => $attendee->peer_address(),
            };
         },
         @_
      );
   } ## end sub get_attendees_details
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::Talk - class to represent a Talk in the WWW::Slides system


=head1 VERSION

This document describes WWW::Slides::Talk version 0.0.3


=head1 SYNOPSIS

   use WWW::Slides::Talk;

   my $talk = WWW::Slides::Talk->new(
      controller => $controller, # e.g. WWW::Slides::Controller::TCP
      port       => 50505,       # where am I acting as HTTP server
      slide_show => $slide_show, # e.g. WWW::Slides::SlideShow
   );
  
  
=head1 DESCRIPTION

=for l'autore, da riempire:
   Fornite una descrizione completa del modulo e delle sue caratteristiche.
   Aiutatevi a strutturare il testo con le sottosezioni (=head2, =head3)
   se necessario.


=head1 INTERFACE 

=for l'autore, da riempire:
   Scrivete una sezione separata che elenchi i componenti pubblici
   dell'interfaccia del modulo. Questi normalmente sono formati o
   dalle subroutine che possono essere esportate, o dai metodi che
   possono essere chiamati su oggetti che appartengono alle classi
   fornite da questo modulo.


=head1 DIAGNOSTICS

=for l'autore, da riempire:
   Elencate qualunque singolo errore o messaggio di avvertimento che
   il modulo può generare, anche quelli che non "accadranno mai".
   Includete anche una spiegazione completa di ciascuno di questi
   problemi, una o più possibili cause e qualunque rimedio
   suggerito.


=over

=item C<< Error message here, perhaps with %s placeholders >>

[Descrizione di un errore]

=item C<< Another error message here >>

[Descrizione di un errore]

[E così via...]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for l'autore, da riempire:
   Una spiegazione completa di qualunque sistema di configurazione
   utilizzato dal modulo, inclusi i nomi e le posizioni dei file di
   configurazione, il significato di ciascuna variabile di ambiente
   utilizzata e proprietà che può essere impostata. Queste descrizioni
   devono anche includere dettagli su eventuali linguaggi di configurazione
   utilizzati.
  
WWW::Slides::Talk requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for l'autore, da riempire:
   Una lista di tutti gli altri moduli su cui si basa questo modulo,
   incluse eventuali restrizioni sulle relative versioni, ed una
   indicazione se il modulo in questione è parte della distribuzione
   standard di Perl, parte della distribuzione del modulo o se
   deve essere installato separatamente.

None.


=head1 INCOMPATIBILITIES

=for l'autore, da riempire:
   Una lista di ciascun modulo che non può essere utilizzato
   congiuntamente a questo modulo. Questa condizione può verificarsi
   a causa di conflitti nei nomi nell'interfaccia, o per concorrenza
   nell'utilizzo delle risorse di sistema o di programma, o ancora
   a causa di limitazioni interne di Perl (ad esempio, molti dei
   moduli che utilizzano filtri al codice sorgente sono mutuamente
   incompatibili).

None reported.


=head1 BUGS AND LIMITATIONS

=for l'autore, da riempire:
   Una lista di tutti i problemi conosciuti relativi al modulo,
   insime a qualche indicazione sul fatto che tali problemi siano
   plausibilmente risolti in una versione successiva. Includete anche
   una lista delle restrizioni sulle funzionalità fornite dal
   modulo: tipi di dati che non si è in grado di gestire, problematiche
   relative all'efficienza e le circostanze nelle quali queste possono
   sorgere, limitazioni pratiche sugli insiemi dei dati, casi
   particolari che non sono (ancora) gestiti, e così via.

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

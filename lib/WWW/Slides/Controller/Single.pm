package WWW::Slides::Controller::Single;
{

   use version; our $VERSION = qv('0.0.3');

   use warnings;
   use strict;
   use Carp;
   use English qw( -no_match_vars );

   use Object::InsideOut;

   # Other recommended modules (uncomment to use):
   #  use IO::Prompt;
   #  use Perl6::Export;
   #  use Perl6::Slurp;
   #  use Perl6::Say;
   #  use Regexp::Autoflags;
   #  use Readonly;

   # Module implementation here
   my @in_handle : Field    # controller handle
     : Std(Name => 'in_handle', Private => 1)
     : Arg(Name => 'in_handle', Mandatory => 1);
   my @out_handle : Field : Std(Name => 'out_handle', Private => 1)
     : Arg(Name => 'out_handle');
   my @buffer : Field : Std(Name => 'buffer', Private => 1);
   my @selector : Field # For selector handling...
      : Set(Name => '_set_selector', Private => 1)
      : Get(Name => 'selector');

   sub _init : Init {
      my $self = shift;
      $self->set_buffer('');
   }

   sub set_selector {
      my ($self, $selector) = @_;
      return unless $self->is_alive();
      $selector->add($self->get_in_handle());
      $self->_set_selector($selector);
      return;
   }

   sub release_selector {
      my $self = shift;
      return unless $self->is_alive();
      $self->selector()->remove($self->get_in_handle());
   }

   sub owns {
      my $self = shift;
      my ($fh) = @_;
      return unless $self->is_alive();
      return $self->get_in_handle() == $fh;
   } ## end sub owns

   sub output {
      my $self = shift;
      my $fh = $self->get_out_handle() or return;
      print {$fh} @_;
      return;
   }

   #-------------- COMMAND EXECUTION FRAMEWORK -------------------------
   my %commands = (
      'nothing' => sub {
         print "nothing\n";
      },

      # Slide transition management
      'first' => sub {
         my $self = shift;
         my ($command, $talk) = @_;
         $talk->show_first(@{$command->{target}});
         $self->output("200 OK\n");
      },
      'last' => sub {
         my $self = shift;
         my ($command, $talk) = @_;
         $talk->show_last(@{$command->{target}});
         $self->output("200 OK\n");
      },
      'next' => sub {
         my $self = shift;
         my ($command, $talk) = @_;
         $talk->show_next(@{$command->{target}});
         $self->output("200 OK\n");
      },
      'previous' => sub {
         my $self = shift;
         my ($command, $talk) = @_;
         $talk->show_previous(@{$command->{target}});
         $self->output("200 OK\n");
      },
      'show' => sub {
         my ($self, $command, $talk) = @_;
         $talk->show($command->{slide});
         $self->output("200 OK\n");
      },

      
      # Attendee management
      'book' => sub {
         my $self = shift;
         my ($command, $talk) = @_;
         $talk->book($command->{code});
         $self->output("200 OK\n");
      },
      'attach' => sub {
         my ($self, $command, $talk) = @_;
         $talk->attach(@{ $command->{target} });
         $self->output("200 OK\n");
      },
      'detach' => sub {
         my ($self, $command, $talk) = @_;
         $talk->detach(@{ $command->{target} });
         $self->output("200 OK\n");
      },
      'clamp' => sub {
         my ($self, $command, $talk) = @_;
         $talk->clamp();
         $self->output("200 OK\n");
      },
      'loose' => sub {
         my ($self, $command, $talk) = @_;
         $talk->loose();
         $self->output("200 OK\n");
      },

      # Requests from far
      'get_current' => sub {
         my ($self, $command, $talk) = @_;
         $self->output('200 OK current=' . $talk->get_current() . "\n");
      },

      'get_attendees' => sub {
         my ($self, $command, $talk) = @_;
         my $output = join "\n", map {
            my @elements;
            while (my ($k, $v) = each %$_) {
               $v = '' unless defined $v;
               push @elements, "$k=$v";
            }
            join ';', @elements;
         } $talk->get_attendees_details();
         $self->output("200 OK\n$output\n");
      },
      
      # Ehr... quit
      'quit' => sub {
         my $self = shift;
         my ($command, $talk) = @_;
         $talk->quit();
      },
   );

   sub execute_command {
      my $self = shift;
      my ($command, $talk) = @_;

      my $cmd = $command->{command};
      $cmd = '' unless defined $cmd;
      if (exists $commands{$cmd}) {
         eval {
            $commands{$cmd}->($self, $command, $talk);
         };
         if ($EVAL_ERROR) {
            $self->output("500 error executing '$cmd': $EVAL_ERROR\n");
         }
      }
      else {
         $self->output("500 command '$cmd' not supported\n");
      }
      
      return;
   }

   sub execute_commands {
      my $self = shift;
      my ($fh, $talk) = @_;

      # Execute each command
      $self->execute_command($_, $talk) for $self->get_commands();

      return;
   } ## end sub execute_commands
   #--------------------------------------------------------------------

   sub parse_command {
      my $self = shift;
      my ($command_string) = @_;
      my $command = {
         map {
            my ($k, $v) = split /=/;
            $v = '' unless defined $v;
            $k => $v;
           } split /[\s;]+/,
         $command_string
      };
      $command->{target} =
         defined($command->{target})
         ? [ split /,/, $command->{target} ]
         : [];
      return $command;
   } ## end sub parse_command

   sub shut_down {
      my $self = shift;
      $self->release_selector();
      $self->get_in_handle()->close() if $self->get_in_handle();
      $self->set_in_handle(undef);
      $self->get_out_handle()->close() if $self->get_out_handle();
      $self->set_out_handle(undef);
      return;
   }

   sub get_commands {
      my $self       = shift;

      # Get new stuff from filehandle, extract full commands
      $self->get_in_handle()->sysread(my $newstuff, 1024);
      my $buffer = $self->get_buffer() . $newstuff;
      my @full_lines = split /\n/, $buffer;
      my $remaining  = '';
      $remaining = pop @full_lines unless substr($buffer, -1) eq "\n";
      $self->set_buffer($remaining);

      # Shut this controller off if received EOF
      $self->shut_down unless length $newstuff;

      # Return parsed commands
      return map { $self->parse_command($_) } @full_lines;
   } ## end sub parse_commands

   sub is_alive {
      my $self = shift;
      return defined($self->get_in_handle());
   }
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::Controller::Single - main base class for controllers based in I/O


=head1 VERSION

This document describes WWW::Slides::Controller::Single version 0.0.3


=head1 SYNOPSIS

    use WWW::Slides::Controller::Single;

    # See WWW::Slides::Controller::STDIO anyway...
    my $controller = WWW::Slides::Controller::Single->new(
      in_handle => \*STDIN,
      out_handle => \*STDOUT,
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
  
WWW::Slides::Controller::Single requires no configuration files or environment 
variables.


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

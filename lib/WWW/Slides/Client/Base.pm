package WWW::Slides::Client::Base;
{

   use version; our $VERSION = qv('0.0.1');

   use warnings;
   use strict;
   use Carp;
   use English qw( -no_match_vars );
   use IO::Select;

   use Object::InsideOut;

   # Module implementation here
   my @in_handle : Field    # controller handle, answers
     : Std(Name => 'in_handle', Private => 1)
     : Arg(Name => 'in_handle', Mandatory => 1);
   my @out_handle : Field    # controller handle, commands
     : Std(Name => 'out_handle', Private => 1)
     : Arg(Name => 'out_handle', Mandatory => 1);

   sub send_command {
      my $self = shift;
      my ($command) = @_;

      $self->get_out_handle()->print($command . "\n");

      my $timeout  = undef;
      my $response = '';
      my $in       = $self->get_in_handle();
      my $sel      = IO::Select->new($in);
      while ($sel->can_read($timeout)) {
         $in->sysread(my $data, 1024);
         if (!length $data) {
            $self->shut_down();
            last;
         }
         $response .= $data;
         $timeout = 0.1;
      } ## end while ($sel->can_read($timeout...

      return $response;
   } ## end sub send_command

   #-------------- COMMAND EXECUTION FRAMEWORK -------------------------
   sub _targetted : Private {
      my $self         = shift;
      my $base_command = shift;
      my $target       = ' target=' . join ',', @_;
      return $self->send_command($base_command . $target);
   } ## end sub _targetted :

   sub next {
      my $self = shift;
      return $self->_targetted('command=next ', @_);
   }

   sub previous {
      my $self = shift;
      return $self->_targetted('command=previous ', @_);
   }

   sub first {
      my $self = shift;
      return $self->_targetted('command=first ', @_);
   }

   sub last {
      my $self = shift;
      return $self->_targetted('command=last ', @_);
   }

   sub show {
      my $self     = shift;
      my $slide_no = shift;
      return $self->_targetted("command=show slide=$slide_no ", @_);
   } ## end sub show

   sub attach {
      my $self = shift;
      return $self->_targetted('command=attach ', @_);
   }

   sub detach {
      my $self = shift;
      return $self->_targetted('command=detach ', @_);
   }

   sub book {
      my $self = shift;
      my $code = shift;
      return $self->send_command("command=book code=$code");
   } ## end sub book

   sub clamp {
      return shift->send_command('command=clamp');
   }

   sub loose {
      return shift->send_command('command=loose');
   }

   sub get_current {
      my $self = shift;
      my $res  = $self->send_command('command=get_current');
      return unless defined $res;
      my ($slide_no) = $res =~ m{(\d+) \s* \z}mxs;
      return $slide_no;
   } ## end sub get_current

   sub get_attendees {
      my $self = shift;
      my $res  = $self->send_command('command=get_attendees');
      return unless defined $res;
      my @attendees = split /\n/, $res;
      shift @attendees;    # status line

      for my $attendee (@attendees) {
         my %data = map { split /=/ } split /;/, $attendee;
         $attendee = \%data;
      } ## end for my $attendee (@att)

      return @attendees if wantarray;
      return \@attendees;
   } ## end sub get_attendees

   sub quit {
      return shift->send_command('command=quit');
   }

   sub shut_down {
      my $self = shift;
      $self->release_selector();
      $self->get_in_handle()->close() if $self->get_in_handle();
      $self->set_in_handle(undef);
      $self->get_out_handle()->close() if $self->get_out_handle();
      $self->set_out_handle(undef);
      return;
   } ## end sub shut_down

   sub is_alive {
      my $self = shift;
      return defined($self->get_in_handle());
   }
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides - [Una riga di descrizione dello scopo del modulo]


=head1 VERSION

This document describes WWW::Slides version 0.0.1


=head1 SYNOPSIS

    use WWW::Slides;

=for l'autore, da riempire:
   Qualche breve esempio con codice che mostri l'utilizzo più comune.
   Questa sezione sarà quella probabilmente più letta, perché molti
   utenti si annoiano a leggere tutta la documentazione, per cui
   è meglio essere il più educativi ed esplicativi possibile.
  
  
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
  
WWW::Slides requires no configuration files or environment variables.


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

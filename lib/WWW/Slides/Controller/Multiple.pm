package WWW::Slides::Controller::Multiple;
{

   use version; our $VERSION = qv('0.0.9');

   use warnings;
   use strict;
   use Carp;

   use Object::InsideOut qw( WWW::Slides::Controller );

   # Other recommended modules (uncomment to use):
   #  use IO::Prompt;
   #  use Perl6::Export;
   #  use Perl6::Slurp;
   #  use Perl6::Say;
   #  use Regexp::Autoflags;
   #  use Readonly;

   # Module implementation here
   my @controllers : Field # Repository for handles
      : Std(Name => 'controllers', Private => 1)
      : Get(Name => 'controllers', Private => 1);

   sub _init : Init {
      my $self = shift;
      $self->set_controllers([]);
   }

   sub is_alive {
      my $self = shift;
      $self->remove(grep { ! $_->is_alive() } @{ $self->controllers() });
      return 1;  # By definition
   }

   sub shut_down {
      my $self = shift;
      $self->release_selector();
      $self->SUPER::shut_down();
      return;
   }

   sub add {
      my $self = shift;
      my $selector = $self->selector();
      my $controllers = $self->controllers();
      for my $controller (@_) {
         push @$controllers, $controller;
         $controller->set_selector($selector) if $selector;
      }
      return;
   }

   sub remove {
      my $self = shift;
      my $selector = $self->selector();
      my @remaining = @{$self->controllers()};
      for my $controller (@_) {
         @remaining = grep { $_ ne $controller } @remaining;
         $controller->release_selector($selector) if $selector;
      }
      $self->set_controllers(\@remaining);
      return;
   }

   sub set_selector {
      my $self = shift;
      my ($selector) = @_;
      $self->SUPER::set_selector($selector);
      $_->set_selector($selector) for @{ $self->controllers() || [] };
      return;
   }

   sub release_selector {
      my $self = shift;
      my $selector = $self->selector() or return;
      $_->release_selector($selector) for @{ $self->controllers() || [] };
      $self->SUPER::release_selector();
      return;
   }

   sub owns {
      my $self = shift;
      my ($fh) = @_;
      return defined $self->get_owner($fh);
   }

   # get_input_chunk not overridden, cannot be called
   # output not overridden, cannot be called

   sub get_owner : Private {
      my $self = shift;
      my ($fh) = @_;
      for my $c (@{ $self->controllers() }) {
         return $c if $c->owns($fh);
      }
      return;
   }

   sub execute_commands { # Get commands from applicable component
      my $self = shift;
      my ($fh, $talk) = @_;
      return $self->get_owner($fh)->execute_commands($fh, $talk);
   } ## end sub get_commands

}
1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::Controller::Multiple - handle multiple controllers as one


=head1 VERSION

This document describes WWW::Slides::Controller::Multiple version 0.0.9


=head1 SYNOPSIS

    use WWW::Slides::Controller::Multiple;

  
=head1 DESCRIPTION

This class is mainly intended as a base class for more specialised
derivatives (e.g. WWW::Slides::Controller::TCP).


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
   il modulo pu� generare, anche quelli che non "accadranno mai".
   Includete anche una spiegazione completa di ciascuno di questi
   problemi, una o pi� possibili cause e qualunque rimedio
   suggerito.


=over

=item C<< Error message here, perhaps with %s placeholders >>

[Descrizione di un errore]

=item C<< Another error message here >>

[Descrizione di un errore]

[E cos� via...]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for l'autore, da riempire:
   Una spiegazione completa di qualunque sistema di configurazione
   utilizzato dal modulo, inclusi i nomi e le posizioni dei file di
   configurazione, il significato di ciascuna variabile di ambiente
   utilizzata e propriet� che pu� essere impostata. Queste descrizioni
   devono anche includere dettagli su eventuali linguaggi di configurazione
   utilizzati.
  
WWW::Slides::Controller::Multiple requires no configuration files or 
environment variables.


=head1 DEPENDENCIES

=for l'autore, da riempire:
   Una lista di tutti gli altri moduli su cui si basa questo modulo,
   incluse eventuali restrizioni sulle relative versioni, ed una
   indicazione se il modulo in questione � parte della distribuzione
   standard di Perl, parte della distribuzione del modulo o se
   deve essere installato separatamente.

None.


=head1 INCOMPATIBILITIES

=for l'autore, da riempire:
   Una lista di ciascun modulo che non pu� essere utilizzato
   congiuntamente a questo modulo. Questa condizione pu� verificarsi
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
   una lista delle restrizioni sulle funzionalit� fornite dal
   modulo: tipi di dati che non si � in grado di gestire, problematiche
   relative all'efficienza e le circostanze nelle quali queste possono
   sorgere, limitazioni pratiche sugli insiemi dei dati, casi
   particolari che non sono (ancora) gestiti, e cos� via.

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 AUTHOR

Flavio Poletti  C<< <flavio [at] polettix [dot] it> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Flavio Poletti C<< <flavio [at] polettix [dot] it> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>
and L<perlgpl>.

Questo modulo � software libero: potete ridistribuirlo e/o
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

Poich� questo software viene dato con una licenza gratuita, non
c'� alcuna garanzia associata ad esso, ai fini e per quanto permesso
dalle leggi applicabili. A meno di quanto possa essere specificato
altrove, il proprietario e detentore del copyright fornisce questo
software "cos� com'�" senza garanzia di alcun tipo, sia essa espressa
o implicita, includendo fra l'altro (senza per� limitarsi a questo)
eventuali garanzie implicite di commerciabilit� e adeguatezza per
uno scopo particolare. L'intero rischio riguardo alla qualit� ed
alle prestazioni di questo software rimane a voi. Se il software
dovesse dimostrarsi difettoso, vi assumete tutte le responsabilit�
ed i costi per tutti i necessari servizi, riparazioni o correzioni.

In nessun caso, a meno che ci� non sia richiesto dalle leggi vigenti
o sia regolato da un accordo scritto, alcuno dei detentori del diritto
di copyright, o qualunque altra parte che possa modificare, o redistribuire
questo software cos� come consentito dalla licenza di cui sopra, potr�
essere considerato responsabile nei vostri confronti per danni, ivi
inclusi danni generali, speciali, incidentali o conseguenziali, derivanti
dall'utilizzo o dall'incapacit� di utilizzo di questo software. Ci�
include, a puro titolo di esempio e senza limitarsi ad essi, la perdita
di dati, l'alterazione involontaria o indesiderata di dati, le perdite
sostenute da voi o da terze parti o un fallimento del software ad
operare con un qualsivoglia altro software. Tale negazione di garanzia
rimane in essere anche se i dententori del copyright, o qualsiasi altra
parte, � stata avvisata della possibilit� di tali danneggiamenti.

Se decidete di utilizzare questo software, lo fate a vostro rischio
e pericolo. Se pensate che i termini di questa negazione di garanzia
non si confacciano alle vostre esigenze, o al vostro modo di
considerare un software, o ancora al modo in cui avete sempre trattato
software di terze parti, non usatelo. Se lo usate, accettate espressamente
questa negazione di garanzia e la piena responsabilit� per qualsiasi
tipo di danno, di qualsiasi natura, possa derivarne.

=cut

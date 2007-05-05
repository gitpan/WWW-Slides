package WWW::Slides::SlideShow;
{
   use version; our $VERSION = qv('0.0.7');

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
   my @filename : Field    # File to read for slides
     : Get(Name => 'filename')    # Public getter
     : Std(Name => 'filename', Private => 1);

   my @preamble : Field           # HTML/whatever preamble
     : Std(Name => 'preamble');
   my @slides : Field             # slide repository
     : Std(Name => 'slides', Private => 1);
   my @postamble : Field          # HTML/whatever postamble
     : Std(Name => 'postamble');

   sub read_line_by_line : Private {
      my $self = shift;
      my ($iterator) = @_;

      my $preamble;
      while (defined $iterator->()) {
         $preamble .= $_;
         last if /<body/msxi;
      }
      $self->set_preamble($preamble);

      my @slides;
      my $slide     = '';
      my $div_id    = '';
      my $div_depth = 0;
      my $div_mark  = 0;
      my $postamble = '';
      while (defined $iterator->()) {
         if (m{</body>}mxsi) {
            $postamble = $_;
            last;
         }
         $slide .= $_;
         if (m{<div[^>]*\sid="([^"]*)"}mxsi) {
            $div_id   = $1;
            $div_mark = $div_depth++;
         }
         elsif (m{<div}mxsi) {
            ++$div_depth;
         }
         if (m{</div>}mxsi) {
            if (--$div_depth == $div_mark) {
               push @slides, {div_id => $div_id, slide => $slide};
               $slide  = '';
               $div_id = '';
            }
         } ## end if (m{</div>}mxsi)
      } ## end while (defined $iterator->...
      $self->set_slides(\@slides);

      $self->set_postamble($postamble . join('', $iterator->()));

      return;
   } ## end sub read_line_by_line :

   sub read_fh : Private {
      my $self = shift;
      my ($fh) = @_;

      return $self->read_line_by_line(
         sub {
            return <$fh> if wantarray;
            return $_ = <$fh>;
         }
      );
   } ## end sub read_fh :

   sub read {
      my $self = shift;
      my ($what) = @_;

      croak "undefined file to read slide show" unless defined $what;

      my ($fh, $was_mine);
      if (ref $what eq 'SCALAR') {    # Straight string, in-memory handle
         $self->set_filename('<string>');
         eval { open $fh, '<', $what or die };    # The perl 5.8 way...

         if ($EVAL_ERROR) {    # Try to use IO::String, if available...
            eval {
               require IO::String;
               $fh = IO::String->new($$what);
            };
         } ## end if ($EVAL_ERROR)

         # I really wouldn't fall back to this, because I've to
         # split it all in advance, but this is the best I can think
         # at the moment
         if ($EVAL_ERROR) {

            # split and re-insert newlines. I don't really mind that
            # I could potentially add a newline to the final line.
            my @lines = map { "$_\n" } split /\n/, $$what;
            return $self->read_line_by_line(
               sub {
                  return splice @lines if wantarray;
                  return $_ = shift @lines;
               }
            );
         } ## end if ($EVAL_ERROR)

         $was_mine = 1;
      } ## end if (ref $what eq 'SCALAR')
      elsif (ref $what eq 'GLOB') {
         $self->set_filename('<filehandle>');
         $fh = $what;
      }
      elsif (ref $what eq 'ARRAY') {    # One file per slide
         $self->set_filename('<various-files>');
         return $self->read_slides(@$what);
      }
      else {
         $self->set_filename($what);
         open $fh, '<', $what
           or croak "can't open('$what'): $OS_ERROR";
         $was_mine = 1;
      } ## end else [ if (ref $what eq 'SCALAR')

      my $retval = $self->read_fh($fh);
      close $fh if $was_mine;

      return $retval;
   } ## end sub read

   sub read_slides {
      my $self = shift;

      $self->set_preamble('
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html>
   <head>
      <title>WWW::Slides presentation</title>
   </head>
   <body>
      ');

      $self->set_postamble("\n</body></html>\n");

      my @slides;
      for my $filename (@_) {
         my $text   = $self->read_slide($filename);
         my $div_id = 'slide' . scalar @slides;
         push @slides,
           {
            div_id => $div_id,
            slide  => qq{\n<div id="$div_id"} . $text . "\n</div>\n"
           };
      } ## end for my $filename (@_)
      $self->set_slides(\@slides);
      return 1;
   } ## end sub read_slides

   sub read_slide {    # append a slide
      my $self = shift;
      my ($filename) = @_;
      require HTML::Parser;
      my $parser = HTML::Parser->new(api_version => 3) or die $!;

      my $text = '';
      my $start_handler = sub {
         my ($tag, $self) = @_;
         return unless lc($tag) eq 'body';
         $self->handler(default => sub { $text .= shift }, 'text');
         $self->handler(start   => sub { $text .= shift }, 'text');
         $self->handler(
            end => sub {
               my ($tagname, $self, $newtext) = @_;
               if (lc($tagname) eq 'body') {
                  $self->eof();
               }
               else {
                  $text .= $newtext if defined $newtext;
               }
            },
            'tagname,self,text'
         );
      };
      $parser->handler(start => $start_handler, 'tagname,self');

      $parser->parse_file($filename)
        or die "could not parse '$filename': $OS_ERROR";
      return $text;
   } ## end sub read_slide

   sub add_headers {    # Headers are ok for the moment
      my $self = shift;
      return;
   }

   sub get_ping {
      return "<!-- MARK -->\n";
   }

   sub get_show_div {
      my $self       = shift;
      my ($slide_no) = @_;
      my $div_id     = $self->_get_slide($slide_no)->{div_id};
      return "<style>#$div_id { display: block }</style>\n";
   } ## end sub get_show_div

   sub get_hide_div {
      my $self       = shift;
      my ($slide_no) = @_;
      my $div_id     = $self->_get_slide($slide_no)->{div_id};
      return "<style>#$div_id { display: none }</style>\n";
   } ## end sub get_hide_div

   sub get_slide {
      my $self = shift;
      my ($slide_no) = @_;
      return $self->_get_slide($slide_no)->{slide};
   }

   sub _get_slide {
      my $self = shift;
      my ($n) = @_;
      return $self->get_slides()->[$n - 1];
   }

   sub id_first {
      return 1;
   }

   sub id_last {
      my $self = shift;
      return scalar @{$self->get_slides()};
   }

   sub id_next {
      my $self = shift;
      my ($id) = @_;
      return ($id + 1) if $self->validate_slide_id($id + 1);
      return $id;
   } ## end sub id_next

   sub id_previous {
      my $self = shift;
      my ($id) = @_;
      return ($id - 1) if $self->validate_slide_id($id - 1);
      return $id;
   } ## end sub id_previous

   sub validate_slide_id {
      my $self = shift;
      my ($id) = @_;
      return if $id !~ /\A\d+\z/;
      return ($id > 0) && ($id <= @{$self->get_slides()});
   } ## end sub validate_slide_id

}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::SlideShow - slide show library for WWW::Slides


=head1 VERSION

This document describes WWW::Slides::SlideShow version 0.0.3


=head1 SYNOPSIS

    use WWW::Slides::SlideShow;

    my $slide_show = WWW::Slides::SlideShow->new();
    $slide_show->read($filename || \*DATA); # read from filename or handle

    # Now you can use it as the 'slide_show' argument when building up
    # a WWW::Slides::Talk object.
  
  
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
  
WWW::Slides::SlideShow requires no configuration files or environment
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
